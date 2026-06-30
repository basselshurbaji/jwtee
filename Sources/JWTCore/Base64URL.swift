import Foundation

/// Helpers for the base64url encoding (RFC 4648 §5) used by JWT.
///
/// JWT uses base64url *without* padding: `+` → `-`, `/` → `_`, and the
/// trailing `=` padding characters are stripped.
public enum Base64URL {

    /// Decodes a base64url string into raw bytes.
    ///
    /// Returns `nil` when the input contains characters outside the
    /// base64url alphabet or is otherwise malformed.
    public static func decode(_ string: String) -> Data? {
        guard !string.isEmpty else { return Data() }

        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Restore the padding that base64url omits.
        let remainder = base64.count % 4
        if remainder > 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }

        return Data(base64Encoded: base64)
    }

    /// Encodes raw bytes as an unpadded base64url string.
    public static func encode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
