import MCP

/// Converts MCP `Tool.Content` blocks into a plain `String` result.
///
/// The bridge uses `String` as `MCPDynamicTool.Output` since `String` conforms
/// to `PromptRepresentable` — no `ToolOutput` wrapper type is needed.
public enum ResultConverter {

    /// Returns the text representation of MCP content blocks.
    ///
    /// - Text blocks are concatenated in order.
    /// - Image/audio blocks produce a MIME-type placeholder.
    /// - Resource blocks use embedded text, or the URI as a fallback.
    /// - If `isError` is true, the result is prefixed with `[error] `.
    public static func string(
        from content: [MCP.Tool.Content],
        isError: Bool?
    ) -> String {
        guard !content.isEmpty else { return "(no content)" }
        let body = content.map { textRepresentation(of: $0) }.joined(separator: "\n")
        return isError == true ? "[error] \(body)" : body
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
