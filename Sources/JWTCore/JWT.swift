import Foundation

/// Errors that can occur while decoding a JWT.
public enum JWTError: Error, Equatable, Sendable {
    /// The token does not have exactly three dot-separated segments.
    case malformedStructure(segmentCount: Int)
    /// A segment was not valid base64url.
    case invalidBase64URL(segment: JWTSegment)
    /// A segment decoded to bytes that were not valid JSON.
    case invalidJSON(segment: JWTSegment)
    /// A decoded segment was valid JSON but not a JSON object.
    case notAJSONObject
}

/// Identifies which part of the token a decoding error refers to.
public enum JWTSegment: String, Sendable {
    case header
    case payload
}

/// A decoded (but not necessarily verified) JSON Web Token.
public struct JWT: Equatable, Sendable {
    /// Decoded header claims (e.g. `alg`, `typ`, `kid`).
    public let header: [String: JSONValue]
    /// Decoded payload claims (e.g. `sub`, `exp`, `iat`).
    public let payload: [String: JSONValue]

    /// The raw `header.payload` string — the bytes that a signature covers.
    public let signingInput: String
    /// The raw, still-encoded signature segment.
    public let rawSignature: String
    /// The decoded signature bytes.
    public let signatureBytes: Data

    /// Decodes a compact-serialized JWT string.
    ///
    /// This performs **no** signature verification — it only parses structure.
    /// Use ``JWTVerifier`` to check the signature.
    public init(token: String) throws {
        let segments = token.split(separator: ".", omittingEmptySubsequences: false)
            .map(String.init)

        guard segments.count == 3 else {
            throw JWTError.malformedStructure(segmentCount: segments.count)
        }

        let (headerSeg, payloadSeg, signatureSeg) = (segments[0], segments[1], segments[2])

        guard let headerData = Base64URL.decode(headerSeg) else {
            throw JWTError.invalidBase64URL(segment: .header)
        }
        guard let payloadData = Base64URL.decode(payloadSeg) else {
            throw JWTError.invalidBase64URL(segment: .payload)
        }

        do {
            self.header = try JSONValue.parseObject(headerData)
        } catch JWTError.notAJSONObject {
            throw JWTError.notAJSONObject
        } catch {
            throw JWTError.invalidJSON(segment: .header)
        }

        do {
            self.payload = try JSONValue.parseObject(payloadData)
        } catch JWTError.notAJSONObject {
            throw JWTError.notAJSONObject
        } catch {
            throw JWTError.invalidJSON(segment: .payload)
        }

        self.signingInput = "\(headerSeg).\(payloadSeg)"
        self.rawSignature = signatureSeg
        self.signatureBytes = Base64URL.decode(signatureSeg) ?? Data()
    }
}

// MARK: - Registered claim accessors

public extension JWT {
    /// The `alg` header value (e.g. `"HS256"`), if present.
    var algorithm: String? { header["alg"]?.stringValue }

    /// The `typ` header value (e.g. `"JWT"`), if present.
    var type: String? { header["typ"]?.stringValue }

    /// The `kid` (key id) header value, if present.
    var keyID: String? { header["kid"]?.stringValue }

    /// `exp` — expiration time, as a `Date`.
    var expiresAt: Date? { date(for: "exp") }

    /// `iat` — issued-at time, as a `Date`.
    var issuedAt: Date? { date(for: "iat") }

    /// `nbf` — not-before time, as a `Date`.
    var notBefore: Date? { date(for: "nbf") }

    /// `sub` — subject.
    var subject: String? { payload["sub"]?.stringValue }

    /// `iss` — issuer.
    var issuer: String? { payload["iss"]?.stringValue }

    /// `jti` — JWT id.
    var jwtID: String? { payload["jti"]?.stringValue }

    /// `aud` — audience. May be a single string or an array of strings.
    var audience: [String] {
        switch payload["aud"] {
        case let .string(value):
            return [value]
        case let .array(values):
            return values.compactMap(\.stringValue)
        default:
            return []
        }
    }

    private func date(for claim: String) -> Date? {
        guard let seconds = payload[claim]?.doubleValue else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }
}

// MARK: - Validity

public extension JWT {
    /// Whether the token is expired relative to `now`.
    ///
    /// Returns `false` when there is no `exp` claim. `now` is injectable to
    /// keep time-based behavior deterministic in tests.
    func isExpired(now: Date = Date()) -> Bool {
        guard let expiresAt else { return false }
        return now >= expiresAt
    }

    /// Whether the token is not yet valid relative to `now` (per `nbf`).
    ///
    /// Returns `false` when there is no `nbf` claim.
    func isNotYetValid(now: Date = Date()) -> Bool {
        guard let notBefore else { return false }
        return now < notBefore
    }

    /// Convenience: the token is within its time window (`nbf` ≤ now < `exp`).
    func isTimeValid(now: Date = Date()) -> Bool {
        !isExpired(now: now) && !isNotYetValid(now: now)
    }
}
