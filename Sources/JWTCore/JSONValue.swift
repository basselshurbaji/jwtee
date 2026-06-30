import Foundation

/// A minimal JSON value model used to represent decoded JWT headers and
/// payloads. Unlike `[String: Any]`, it is `Equatable` and `Sendable`, which
/// makes it convenient to assert against in tests and pass across actors.
public enum JSONValue: Equatable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    /// Parses a JSON object (the only shape valid for a JWT header/payload)
    /// from raw bytes.
    static func parseObject(_ data: Data) throws -> [String: JSONValue] {
        let raw = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dictionary = raw as? [String: Any] else {
            throw JWTError.notAJSONObject
        }
        return dictionary.mapValues(JSONValue.init(any:))
    }

    init(any: Any) {
        switch any {
        case let value as String:
            self = .string(value)
        case let value as Bool where type(of: any) == type(of: true):
            // NSNumber bridges bools and numbers; disambiguate explicitly.
            self = .bool(value)
        case let value as NSNumber:
            // CFBoolean is an NSNumber subclass; detect it via the type id.
            if CFGetTypeID(value) == CFBooleanGetTypeID() {
                self = .bool(value.boolValue)
            } else {
                self = .number(value.doubleValue)
            }
        case let value as [Any]:
            self = .array(value.map(JSONValue.init(any:)))
        case let value as [String: Any]:
            self = .object(value.mapValues(JSONValue.init(any:)))
        case is NSNull:
            self = .null
        default:
            self = .null
        }
    }

    /// The value as a `Double`, when it is a JSON number.
    public var doubleValue: Double? {
        if case let .number(value) = self { return value }
        return nil
    }

    /// The value as a `String`, when it is a JSON string.
    public var stringValue: String? {
        if case let .string(value) = self { return value }
        return nil
    }
}
