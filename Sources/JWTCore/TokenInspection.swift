import Foundation

/// A display-ready summary of a token: pretty-printed header/payload, a few
/// highlighted claims, time validity, and (optionally) a signature verdict.
///
/// This lives in the core (not the UI layer) so it can be unit-tested without
/// instantiating any SwiftUI views.
public struct TokenInspection: Equatable, Sendable {

    /// A single highlighted claim shown in the summary panel.
    public struct Highlight: Equatable, Sendable {
        public let label: String
        public let value: String
    }

    public let prettyHeader: String
    public let prettyPayload: String
    public let highlights: [Highlight]
    /// `nil` when the token has no `exp` claim.
    public let isExpired: Bool?
    /// `nil` when the token has no `nbf` claim.
    public let isNotYetValid: Bool?

    /// Builds an inspection from an already-decoded token, evaluating time
    /// claims relative to `now` (injectable for tests).
    public init(jwt: JWT, now: Date = Date()) {
        self.prettyHeader = TokenInspection.prettyJSON(jwt.header)
        self.prettyPayload = TokenInspection.prettyJSON(jwt.payload)
        self.isExpired = jwt.expiresAt == nil ? nil : jwt.isExpired(now: now)
        self.isNotYetValid = jwt.notBefore == nil ? nil : jwt.isNotYetValid(now: now)

        var highlights: [Highlight] = []
        func add(_ label: String, _ value: String?) {
            if let value, !value.isEmpty { highlights.append(Highlight(label: label, value: value)) }
        }
        add("Algorithm", jwt.algorithm)
        add("Type", jwt.type)
        add("Key ID", jwt.keyID)
        add("Issuer", jwt.issuer)
        add("Subject", jwt.subject)
        if !jwt.audience.isEmpty { add("Audience", jwt.audience.joined(separator: ", ")) }
        add("Issued at", jwt.issuedAt.map { TokenInspection.format($0, now: now) })
        add("Not before", jwt.notBefore.map { TokenInspection.format($0, now: now) })
        add("Expires at", jwt.expiresAt.map { TokenInspection.format($0, now: now) })
        self.highlights = highlights
    }

    /// Formats a claim timestamp in the viewer's *local* time, followed by a
    /// relative phrase (e.g. "in 8 years" / "3 months ago"). The raw epoch /
    /// UTC value is always available in the payload JSON.
    private static func format(_ date: Date, now: Date) -> String {
        let absolute = DateFormatter()
        absolute.dateStyle = .medium
        absolute.timeStyle = .short // uses the current locale + local time zone

        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .full

        return "\(absolute.string(from: date)) (\(relative.localizedString(for: date, relativeTo: now)))"
    }

    /// Pretty-prints a decoded claims object with sorted, indented keys.
    static func prettyJSON(_ object: [String: JSONValue]) -> String {
        let foundation = object.mapValues(toFoundation)
        guard
            let data = try? JSONSerialization.data(
                withJSONObject: foundation,
                options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            )
        else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }

    private static func toFoundation(_ value: JSONValue) -> Any {
        switch value {
        case let .string(string): return string
        case let .number(number):
            // Render integers without a trailing ".0".
            if number == number.rounded() && abs(number) < 1e15 {
                return Int(number)
            }
            return number
        case let .bool(bool): return bool
        case let .object(object): return object.mapValues(toFoundation)
        case let .array(array): return array.map(toFoundation)
        case .null: return NSNull()
        }
    }
}
