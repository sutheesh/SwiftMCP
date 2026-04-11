import MCP

/// Converts MCP `Tool.Content` blocks into a plain `String` result.
///
/// `String` is used as `MCPDynamicTool.Output` because it conforms to
/// `PromptRepresentable`, which lets Foundation Models include the result
/// directly in the conversation context.
///
/// ## Content Block Mapping
///
/// | MCP Content Type | String Output |
/// |---|---|
/// | `.text` | The text verbatim |
/// | `.image` | `[image:<mimeType>]` placeholder |
/// | `.audio` | `[audio:<mimeType>]` placeholder |
/// | `.resource` | Embedded text, or `[resource:<uri>]` fallback |
/// | `.resourceLink` | `[resource:<name> <uri>]` |
public enum ResultConverter {

    /// Returns the text representation of MCP content blocks.
    ///
    /// - Parameters:
    ///   - content: One or more MCP tool content blocks.
    ///   - isError: When `true`, the result is prefixed with `[error] `.
    /// - Returns: A single string suitable for use as `LanguageModelSession` tool output.
    public static func string(
        from content: [MCP.Tool.Content],
        isError: Bool?
    ) -> String {
        guard !content.isEmpty else { return "(no content)" }
        let body = content.map { textRepresentation(of: $0) }.joined(separator: "\n")
        return isError == true ? "[error] \(body)" : body
    }

    /// Returns a graceful error string when an MCP tool call fails at the
    /// transport or server level.
    ///
    /// Used by `MCPDynamicTool.call(arguments:)` to keep the
    /// `LanguageModelSession` running rather than throwing.
    static func toolCallError(tool: String, error: Error) -> String {
        "[error] Tool '\(tool)' failed: \(error.localizedDescription)"
    }

    // MARK: - Private

    private static func textRepresentation(of block: MCP.Tool.Content) -> String {
        switch block {
        case .text(let text, _, _):
            return text
        case .image(_, let mimeType, _, _):
            return "[image:\(mimeType)]"
        case .audio(_, let mimeType, _, _):
            return "[audio:\(mimeType)]"
        case .resource(let resource, _, _):
            return resource.text ?? "[resource:\(resource.uri)]"
        case .resourceLink(let uri, let name, _, _, _, _):
            return "[resource:\(name) \(uri)]"
        }
    }
}
