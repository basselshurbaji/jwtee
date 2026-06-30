import Foundation
import JWTCore

/// Shared test fixtures.
enum Fixtures {
    /// The canonical example token from jwt.io, signed with the UTF-8 secret
    /// `your-256-bit-secret`. External ground truth.
    static let canonicalHS256 =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9" +
        ".eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ" +
        ".SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
    static let canonicalSecret = "your-256-bit-secret"

    /// Builds a compact JWT from header/payload dictionaries, signing it with
    /// `secret` using `algorithm`.
    static func make(
        header: [String: Any] = [:],
        payload: [String: Any],
        secret: String,
        algorithm: HMACAlgorithm
    ) -> String {
        var fullHeader = header
        fullHeader["alg"] = algorithm.rawValue
        if fullHeader["typ"] == nil { fullHeader["typ"] = "JWT" }

        let headerSeg = Base64URL.encode(json(fullHeader))
        let payloadSeg = Base64URL.encode(json(payload))
        let signingInput = "\(headerSeg).\(payloadSeg)"

        let sig = JWTVerifier.signature(
            for: Data(signingInput.utf8),
            key: Data(secret.utf8),
            algorithm: algorithm
        )
        return "\(signingInput).\(Base64URL.encode(sig))"
    }

    /// A token whose payload was altered after signing (admin escalated to
    /// `true`), keeping the now-stale signature.
    static func tampered(secret: String) -> String {
        let token = make(payload: ["sub": "alice", "admin": false], secret: secret, algorithm: .hs256)
        var segments = token.split(separator: ".").map(String.init)
        segments[1] = Base64URL.encode(json(["sub": "alice", "admin": true]))
        return segments.joined(separator: ".")
    }

    /// Builds a token then decodes it, for convenience in claim tests.
    static func decoded(payload: [String: Any], secret: String = "test-secret") throws -> JWT {
        try JWT(token: make(payload: payload, secret: secret, algorithm: .hs256))
    }

    static func json(_ object: [String: Any]) -> Data {
        (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) ?? Data()
    }
}
