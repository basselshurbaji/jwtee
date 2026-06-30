import Foundation
import CryptoKit

/// The HMAC signing algorithms this tool can verify. JWTs that use a shared
/// *secret* (rather than a public/private key pair) use the `HS*` family.
public enum HMACAlgorithm: String, Sendable, CaseIterable {
    case hs256 = "HS256"
    case hs384 = "HS384"
    case hs512 = "HS512"
}

/// The outcome of verifying a token's signature.
public enum VerificationResult: Equatable, Sendable {
    /// The signature matches the secret over the signing input.
    case valid
    /// The signature does not match.
    case invalid
    /// The token's `alg` is missing or not an HMAC algorithm we support
    /// (e.g. `RS256`, `ES256`, or `none`). The associated value is the raw
    /// `alg` header, if any.
    case unsupportedAlgorithm(String?)

    public var isValid: Bool { self == .valid }
}

/// How the provided secret should be interpreted.
public enum SecretEncoding: Sendable {
    /// Treat the secret string as UTF-8 bytes (jwt.io's default).
    case utf8
    /// Treat the secret string as base64-encoded bytes.
    case base64
}

/// Verifies JWT signatures for the HMAC (`HS256`/`HS384`/`HS512`) family.
public enum JWTVerifier {

    /// Verifies `token`'s signature against `secret`.
    ///
    /// - Parameters:
    ///   - token: The decoded token.
    ///   - secret: The shared secret.
    ///   - encoding: How to interpret `secret`. Defaults to UTF-8.
    public static func verify(
        _ token: JWT,
        secret: String,
        encoding: SecretEncoding = .utf8
    ) -> VerificationResult {
        guard
            let algString = token.algorithm,
            let algorithm = HMACAlgorithm(rawValue: algString)
        else {
            return .unsupportedAlgorithm(token.algorithm)
        }

        guard let keyData = secretData(secret, encoding: encoding) else {
            // A secret that doesn't decode as base64 can't match anything.
            return .invalid
        }

        let expected = signature(
            for: Data(token.signingInput.utf8),
            key: keyData,
            algorithm: algorithm
        )

        // Constant-time comparison to avoid leaking via timing.
        let matches = constantTimeEquals(expected, token.signatureBytes)
        return matches ? .valid : .invalid
    }

    /// Computes the raw HMAC signature bytes for a signing input.
    public static func signature(for message: Data, key: Data, algorithm: HMACAlgorithm) -> Data {
        let symmetricKey = SymmetricKey(data: key)
        switch algorithm {
        case .hs256:
            return Data(HMAC<SHA256>.authenticationCode(for: message, using: symmetricKey))
        case .hs384:
            return Data(HMAC<SHA384>.authenticationCode(for: message, using: symmetricKey))
        case .hs512:
            return Data(HMAC<SHA512>.authenticationCode(for: message, using: symmetricKey))
        }
    }

    private static func secretData(_ secret: String, encoding: SecretEncoding) -> Data? {
        switch encoding {
        case .utf8:
            return Data(secret.utf8)
        case .base64:
            return Data(base64Encoded: secret)
        }
    }

    private static func constantTimeEquals(_ lhs: Data, _ rhs: Data) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var difference: UInt8 = 0
        for (a, b) in zip(lhs, rhs) {
            difference |= a ^ b
        }
        return difference == 0
    }
}
