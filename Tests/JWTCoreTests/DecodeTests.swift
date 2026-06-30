import Foundation
import Testing
@testable import JWTCore

@Suite("Base64URL")
struct Base64URLTests {
    @Test("round-trips arbitrary bytes without padding chars")
    func roundTrip() {
        let data = Data("The quick brown fox 🦊".utf8)
        let encoded = Base64URL.encode(data)
        #expect(!encoded.contains("="))
        #expect(!encoded.contains("+") && !encoded.contains("/"))
        #expect(Base64URL.decode(encoded) == data)
    }

    @Test("decodes a real JWT header segment")
    func decodesHeaderSegment() {
        let decoded = Base64URL.decode("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9")
        #expect(decoded.map { String(decoding: $0, as: UTF8.self) } == #"{"alg":"HS256","typ":"JWT"}"#)
    }

    @Test("empty string decodes to empty data")
    func emptyDecodes() {
        #expect(Base64URL.decode("") == Data())
    }

    @Test("invalid characters return nil")
    func invalidReturnsNil() {
        #expect(Base64URL.decode("***") == nil)
    }

    @Test("round-trips bytes needing +/ substitutions")
    func urlSafeSubstitutions() {
        let data = Data([0xFB, 0xFF, 0xBF])
        let encoded = Base64URL.encode(data)
        #expect(encoded.contains("-") || encoded.contains("_"))
        #expect(Base64URL.decode(encoded) == data)
    }
}

@Suite("JWT decoding")
struct JWTDecodingTests {
    @Test("decodes header claims")
    func headerClaims() throws {
        let jwt = try JWT(token: Fixtures.canonicalHS256)
        #expect(jwt.algorithm == "HS256")
        #expect(jwt.type == "JWT")
    }

    @Test("decodes payload claims")
    func payloadClaims() throws {
        let jwt = try JWT(token: Fixtures.canonicalHS256)
        #expect(jwt.subject == "1234567890")
        #expect(jwt.payload["name"]?.stringValue == "John Doe")
        #expect(jwt.issuedAt == Date(timeIntervalSince1970: 1_516_239_022))
    }

    @Test("exposes signing input and signature")
    func signingInputAndSignature() throws {
        let jwt = try JWT(token: Fixtures.canonicalHS256)
        #expect(jwt.rawSignature == "SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c")
        #expect(!jwt.signatureBytes.isEmpty)
    }
}

@Suite("Malformed input")
struct MalformedInputTests {
    @Test("too few segments throws")
    func tooFewSegments() {
        #expect(throws: JWTError.malformedStructure(segmentCount: 2)) {
            try JWT(token: "abc.def")
        }
    }

    @Test("too many segments throws")
    func tooManySegments() {
        #expect(throws: JWTError.malformedStructure(segmentCount: 4)) {
            try JWT(token: "a.b.c.d")
        }
    }

    @Test("empty string throws")
    func emptyString() {
        #expect(throws: JWTError.malformedStructure(segmentCount: 1)) {
            try JWT(token: "")
        }
    }

    @Test("invalid base64url header throws")
    func invalidBase64URLHeader() {
        #expect(throws: JWTError.invalidBase64URL(segment: .header)) {
            try JWT(token: "!!!.eyJ9.sig")
        }
    }

    @Test("non-JSON payload throws")
    func nonJSONPayload() {
        let header = Base64URL.encode(Data(#"{"alg":"HS256"}"#.utf8))
        let payload = Base64URL.encode(Data("hello".utf8))
        #expect(throws: JWTError.invalidJSON(segment: .payload)) {
            try JWT(token: "\(header).\(payload).sig")
        }
    }

    @Test("JSON array payload throws notAJSONObject")
    func jsonArrayPayload() {
        let header = Base64URL.encode(Data(#"{"alg":"HS256"}"#.utf8))
        let payload = Base64URL.encode(Data("[1,2,3]".utf8))
        #expect(throws: JWTError.notAJSONObject) {
            try JWT(token: "\(header).\(payload).sig")
        }
    }
}
