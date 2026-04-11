import Foundation
import MCP

/// Parses a JSON string produced by `GeneratedContent.jsonString` into
/// `[String: MCP.Value]` for forwarding to an MCP server's `callTool` method.
enum ArgumentParser {

    /// Converts a JSON object string into a `[String: MCP.Value]` dictionary.
    ///
    /// Empty input, `{}`, and `"null"` are treated as "no arguments" and return
    /// an empty dictionary rather than throwing.
    ///
    /// - Parameter json: A JSON string from `GeneratedContent.jsonString`.
    /// - Returns: A dictionary of MCP values, or `[:]` if the input is empty.
    /// - Throws: `MCPBridgeError.invalidArgumentsJSON` if `json` is not a valid JSON object.
    static func parse(_ json: String) throws -> [String: MCP.Value] {
        let trimmed = json.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "{}", trimmed != "null" else { return [:] }

        guard let data = trimmed.data(using: .utf8) else {
            throw MCPBridgeError.invalidArgumentsJSON("Could not encode string as UTF-8")
        }
        let raw = try JSONSerialization.jsonObject(with: data)
        guard let dict = raw as? [String: Any] else {
            throw MCPBridgeError.invalidArgumentsJSON("Top-level value must be a JSON object, got: \(type(of: raw))")
        }
        return try dict.reduce(into: [:]) { acc, pair in
            acc[pair.key] = try MCP.Value(anyValue: pair.value)
        }
    }
}
