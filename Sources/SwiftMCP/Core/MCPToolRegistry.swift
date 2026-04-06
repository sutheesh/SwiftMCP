import MCP

/// Caches tool definitions discovered from MCP servers, keyed by
/// `"<serverIdentifier>/<toolName>"`.
///
/// The registry provides O(1) tool lookups and avoids redundant `listTools`
/// round-trips when multiple `LanguageModelSession` instances use the same servers.
actor MCPToolRegistry {

    private var cache: [String: MCP.Tool] = [:]

    // MARK: - Write

    /// Stores a batch of tools discovered from a single server.
    func register(_ tools: [MCP.Tool], from config: MCPServerConfig) {
        for tool in tools {
            cache[key(config: config, toolName: tool.name)] = tool
        }
    }

    // MARK: - Read

    /// Returns the cached definition for a specific tool, or `nil` if not found.
    func tool(named name: String, on config: MCPServerConfig) -> MCP.Tool? {
        cache[key(config: config, toolName: name)]
    }

    /// Returns all cached tools for a given server.
    func allTools(for config: MCPServerConfig) -> [MCP.Tool] {
        let prefix = config.identifier + "/"
        return cache
            .filter { $0.key.hasPrefix(prefix) }
            .map(\.value)
    }

    // MARK: - Invalidation

    /// Removes all cached tools for `config`, forcing re-discovery on next use.
    func invalidate(config: MCPServerConfig) {
        let prefix = config.identifier + "/"
        cache = cache.filter { !$0.key.hasPrefix(prefix) }
    }

    func invalidateAll() {
        cache.removeAll()
    }

    // MARK: - Helpers

    private func key(config: MCPServerConfig, toolName: String) -> String {
        "\(config.identifier)/\(toolName)"
    }
}
