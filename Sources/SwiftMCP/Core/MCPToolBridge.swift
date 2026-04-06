import MCP
import OSLog

private let logger = Logger(subsystem: "com.swiftmcp", category: "MCPToolBridge")

#if canImport(FoundationModels)
import FoundationModels

// MARK: - MCPToolBridge

/// The top-level bridge between the MCP ecosystem and Apple's Foundation Models.
///
/// `MCPToolBridge` connects to one or more MCP servers, discovers their tools,
/// and returns Foundation Models–compatible `Tool` wrappers ready for
/// `LanguageModelSession`.
///
/// ## Usage
///
/// ```swift
/// import SwiftMCP
/// import FoundationModels
///
/// let bridge = try await MCPToolBridge.connect(to: [
///     .http(URL(string: "https://weather.mcp.server")!),
///     .http(URL(string: "https://stocks.mcp.server")!),
/// ])
///
/// let session = LanguageModelSession(tools: bridge.tools)
///
/// let response = try await session.respond(
///     to: "What's the weather in Dallas and should I buy AAPL?"
/// )
/// ```
///
/// ## Connection Lifetime
///
/// The returned `BridgeResult` owns the session manager that keeps all MCP
/// connections (and stdio child processes) alive. Retain it for as long as
/// you use the `LanguageModelSession`.
@available(iOS 26.0, macOS 26.0, *)
public enum MCPToolBridge {

    /// Connects to each server in `configs`, discovers all tools, and returns
    /// a `BridgeResult` containing the Foundation Models tools and the
    /// connection manager that must be retained for the session lifetime.
    ///
    /// - Parameter configs: One or more MCP server configurations.
    /// - Throws: `MCPBridgeError` if any connection or tool-listing fails.
    public static func connect(
        to configs: [MCPServerConfig]
    ) async throws -> BridgeResult {
        let sessionManager = MCPSessionManager()
        var allTools: [any FoundationModels.Tool] = []

        for config in configs {
            let client = try await sessionManager.client(for: config)
            let mcpTools = try await sessionManager.listTools(for: config)

            for mcpTool in mcpTools {
                let wrapper = try MCPDynamicTool(mcpTool: mcpTool, client: client)
                allTools.append(wrapper)
                logger.debug("Registered tool '\(wrapper.name)' from \(config.identifier)")
            }
        }

        logger.info("MCPToolBridge: \(allTools.count) tool(s) ready across \(configs.count) server(s)")
        return BridgeResult(tools: allTools, sessionManager: sessionManager)
    }

    /// Convenience overload for a single server.
    public static func connect(
        to config: MCPServerConfig
    ) async throws -> BridgeResult {
        try await connect(to: [config])
    }
}

// MARK: - BridgeResult

/// Bundles the discovered Foundation Models tools with the connection manager
/// that keeps MCP server connections alive.
///
/// Keep this value in scope for as long as you use the `LanguageModelSession`.
/// Releasing it disconnects from all MCP servers and terminates any stdio
/// child processes.
@available(iOS 26.0, macOS 26.0, *)
public final class BridgeResult: Sendable {

    /// Foundation Models–compatible tools discovered from the MCP servers.
    /// Pass directly to `LanguageModelSession(tools:)`.
    public let tools: [any FoundationModels.Tool]

    private let sessionManager: MCPSessionManager

    init(tools: [any FoundationModels.Tool], sessionManager: MCPSessionManager) {
        self.tools = tools
        self.sessionManager = sessionManager
    }

    deinit {
        let manager = sessionManager
        Task { await manager.disconnectAll() }
    }
}

#endif // canImport(FoundationModels)
