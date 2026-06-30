import Foundation
import Testing
@testable import JWTCore

@Suite("HS256 verification (external ground truth)")
struct HS256Tests {
    @Test("valid secret verifies")
    func validSecret() throws {
        let jwt = try JWT(token: Fixtures.canonicalHS256)
        #expect(JWTVerifier.verify(jwt, secret: Fixtures.canonicalSecret) == .valid)
    }

    @Test("wrong secret is invalid")
    func wrongSecret() throws {
        let jwt = try JWT(token: Fixtures.canonicalHS256)
        #expect(JWTVerifier.verify(jwt, secret: "not-the-secret") == .invalid)
    }
}

@Suite("HMAC round trips")
struct HMACRoundTripTests {
    @Test("HS384/HS512 verify with the correct secret only",
          arguments: [HMACAlgorithm.hs384, .hs512])
    func roundTrip(algorithm: HMACAlgorithm) throws {
        let secret = "a-very-strong-secret"
        let jwt = try JWT(token: Fixtures.make(payload: ["sub": "carol"], secret: secret, algorithm: algorithm))
        #expect(jwt.algorithm == algorithm.rawValue)
        #expect(JWTVerifier.verify(jwt, secret: secret) == .valid)
        #expect(JWTVerifier.verify(jwt, secret: "wrong") == .invalid)
    }
}

@Suite("Tampering & unsupported algorithms")
struct TamperingTests {
    @Test("tampered payload fails verification")
    func tamperedPayload() throws {
        let secret = "tamper-secret"
        let jwt = try JWT(token: Fixtures.tampered(secret: secret))
        #expect(jwt.payload["admin"] == .bool(true))
        #expect(JWTVerifier.verify(jwt, secret: secret) == .invalid)
    }

    @Test("RS256 reports unsupported algorithm")
    func rs256Unsupported() throws {
        let header = Base64URL.encode(Data(#"{"alg":"RS256","typ":"JWT"}"#.utf8))
        let payload = Base64URL.encode(Data(#"{"sub":"x"}"#.utf8))
        let jwt = try JWT(token: "\(header).\(payload).sig")
        #expect(JWTVerifier.verify(jwt, secret: "any") == .unsupportedAlgorithm("RS256"))
    }

    @Test("alg=none reports unsupported algorithm")
    func noneUnsupported() throws {
        let header = Base64URL.encode(Data(#"{"alg":"none"}"#.utf8))
        let payload = Base64URL.encode(Data(#"{"sub":"x"}"#.utf8))
        let jwt = try JWT(token: "\(header).\(payload).")
        #expect(JWTVerifier.verify(jwt, secret: "any") == .unsupportedAlgorithm("none"))
    }
}

@Suite("Secret encodings")
struct SecretEncodingTests {
    @Test("base64-encoded secret matches the same raw bytes")
    func base64Secret() throws {
        let rawSecret = "binary-secret-bytes"
        let base64Secret = Data(rawSecret.utf8).base64EncodedString()
        let jwt = try JWT(token: Fixtures.make(payload: ["sub": "e"], secret: rawSecret, algorithm: .hs256))
        #expect(JWTVerifier.verify(jwt, secret: base64Secret, encoding: .base64) == .valid)
        #expect(JWTVerifier.verify(jwt, secret: base64Secret, encoding: .utf8) == .invalid)
    }

    @Test("invalid base64 secret is invalid, not a crash")
    func invalidBase64Secret() throws {
        let jwt = try JWT(token: Fixtures.canonicalHS256)
        #expect(JWTVerifier.verify(jwt, secret: "!!!not base64!!!", encoding: .base64) == .invalid)
    }
}
