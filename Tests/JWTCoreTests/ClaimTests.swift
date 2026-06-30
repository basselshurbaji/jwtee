import Foundation
import Testing
@testable import JWTCore

@Suite("Expiry (exp)")
struct ExpiryTests {
    @Test("expired token detected")
    func expired() throws {
        let jwt = try Fixtures.decoded(payload: ["exp": 1_000])
        let now = Date(timeIntervalSince1970: 2_000)
        #expect(jwt.isExpired(now: now))
        #expect(!jwt.isTimeValid(now: now))
    }

    @Test("not-yet-expired token is valid")
    func notExpired() throws {
        let jwt = try Fixtures.decoded(payload: ["exp": 5_000])
        let now = Date(timeIntervalSince1970: 2_000)
        #expect(!jwt.isExpired(now: now))
        #expect(jwt.isTimeValid(now: now))
    }

    @Test("expiry boundary is inclusive")
    func boundaryInclusive() throws {
        let jwt = try Fixtures.decoded(payload: ["exp": 3_000])
        #expect(jwt.isExpired(now: Date(timeIntervalSince1970: 3_000)))
    }

    @Test("no exp claim is never expired")
    func noExpClaim() throws {
        let jwt = try Fixtures.decoded(payload: ["sub": "x"])
        #expect(jwt.expiresAt == nil)
        #expect(!jwt.isExpired(now: Date(timeIntervalSince1970: 9_999_999_999)))
    }
}

@Suite("Not-before (nbf)")
struct NotBeforeTests {
    @Test("rejects early use")
    func rejectsEarly() throws {
        let jwt = try Fixtures.decoded(payload: ["nbf": 5_000, "exp": 9_000])
        let now = Date(timeIntervalSince1970: 1_000)
        #expect(jwt.isNotYetValid(now: now))
        #expect(!jwt.isTimeValid(now: now))
    }

    @Test("allows later use")
    func allowsLater() throws {
        let jwt = try Fixtures.decoded(payload: ["nbf": 5_000, "exp": 9_000])
        let now = Date(timeIntervalSince1970: 6_000)
        #expect(!jwt.isNotYetValid(now: now))
        #expect(jwt.isTimeValid(now: now))
    }
}

@Suite("Registered claims")
struct RegisteredClaimTests {
    @Test("issued-at and expires-at dates")
    func dates() throws {
        let jwt = try Fixtures.decoded(payload: ["iat": 1_516_239_022, "exp": 1_516_242_622])
        #expect(jwt.issuedAt == Date(timeIntervalSince1970: 1_516_239_022))
        #expect(jwt.expiresAt == Date(timeIntervalSince1970: 1_516_242_622))
    }

    @Test("audience as single string")
    func audienceString() throws {
        #expect(try Fixtures.decoded(payload: ["aud": "api.example.com"]).audience == ["api.example.com"])
    }

    @Test("audience as array")
    func audienceArray() throws {
        let jwt = try Fixtures.decoded(payload: ["aud": ["a.example.com", "b.example.com"]])
        #expect(jwt.audience == ["a.example.com", "b.example.com"])
    }

    @Test("audience missing is empty")
    func audienceMissing() throws {
        #expect(try Fixtures.decoded(payload: ["sub": "x"]).audience == [])
    }

    @Test("issuer, subject and jti")
    func identifiers() throws {
        let jwt = try Fixtures.decoded(payload: ["iss": "auth-server", "sub": "user-42", "jti": "abc-123"])
        #expect(jwt.issuer == "auth-server")
        #expect(jwt.subject == "user-42")
        #expect(jwt.jwtID == "abc-123")
    }
}

@Suite("TokenInspection")
struct TokenInspectionTests {
    @Test("highlights common claims")
    func highlights() throws {
        let inspection = TokenInspection(jwt: try JWT(token: Fixtures.canonicalHS256))
        let labels = inspection.highlights.map(\.label)
        #expect(labels.contains("Algorithm"))
        #expect(labels.contains("Subject"))
        #expect(inspection.highlights.first { $0.label == "Subject" }?.value == "1234567890")
    }

    @Test("integers render without trailing decimal")
    func integers() throws {
        let inspection = TokenInspection(jwt: try Fixtures.decoded(payload: ["iat": 1_516_239_022]))
        #expect(inspection.prettyPayload.contains("\"iat\" : 1516239022"))
        #expect(!inspection.prettyPayload.contains("1516239022.0"))
    }

    @Test("expiry reflected relative to now")
    func expiryRelativeToNow() throws {
        let jwt = try Fixtures.decoded(payload: ["exp": 1_000])
        #expect(TokenInspection(jwt: jwt, now: Date(timeIntervalSince1970: 2_000)).isExpired == true)
        #expect(TokenInspection(jwt: jwt, now: Date(timeIntervalSince1970: 500)).isExpired == false)
    }

    @Test("no time claims leave validity nil")
    func noTimeClaims() throws {
        let inspection = TokenInspection(jwt: try Fixtures.decoded(payload: ["sub": "x"]))
        #expect(inspection.isExpired == nil)
        #expect(inspection.isNotYetValid == nil)
    }

    @Test("pretty payload is sorted and indented")
    func prettySorted() throws {
        let payload = TokenInspection(jwt: try Fixtures.decoded(payload: ["b": "2", "a": "1"])).prettyPayload
        let aIndex = payload.range(of: "\"a\"")!.lowerBound
        let bIndex = payload.range(of: "\"b\"")!.lowerBound
        #expect(aIndex < bIndex)
        #expect(payload.contains("\n"))
    }
}
