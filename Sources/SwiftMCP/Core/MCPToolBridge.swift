import MCP

#if canImport(FoundationModels)
import FoundationModels

// MARK: - MCPToolBridge

/// The top-level bridge between the MCP ecosystem and Apple's Foundation Models.
///
/// `MCPToolBridge` connects to one or more MCP servers, discovers their tools,
/// and returns Foundation Models–compatible `Tool` wrappers ready for use with
/// `LanguageModelSession`.
///
/// ## Quick Start
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
/// The returned ``BridgeResult`` owns the session manager that keeps all MCP
/// connections (and stdio child processes) alive. Retain it for as long as
/// you use the `LanguageModelSession`. When the `BridgeResult` is deallocated,
/// all connections are closed and stdio subprocesses are terminated.
///
/// ```swift
/// class MyViewModel: ObservableObject {
///     private var bridge: BridgeResult?   // keep alive!
///     private var session: LanguageModelSession?
///
///     func setup() async throws {
///         bridge  = try await MCPToolBridge.connect(to: [...])
///         session = LanguageModelSession(tools: bridge!.tools)
///     }
/// }
/// ```
///
/// ## Error Handling
///
/// ```swift
/// do {
///     let bridge = try await MCPToolBridge.connect(to: [.http(url)])
/// } catch MCPBridgeError.connectionFailed(let server, let error) {
///     print("Could not connect to \(server): \(error)")
/// } catch MCPBridgeError.schemaConversionFailed(let tool, let error) {
///     print("Schema error for tool '\(tool)': \(error)")
/// }
/// ```
@available(iOS 26.0, macOS 26.0, *)
public enum MCPToolBridge {

    /// Connects to each server in `configs`, discovers all tools, and returns
    /// a ``BridgeResult`` containing the Foundation Models tools and the
    /// connection manager.
    ///
    /// The call connects to servers concurrently and lists their tools with
    /// automatic cursor-based pagination. Tool names are sanitised to conform
    /// to Foundation Models' identifier requirements (alphanumeric + `_`).
    ///
    /// - Parameter configs: One or more MCP server configurations. Use
    ///   ``MCPServerConfig/http(_:headers:)`` for remote servers and
    ///   ``MCPServerConfig/stdio(executablePath:arguments:environment:)`` for
    ///   local subprocesses (macOS only).
    /// - Returns: A ``BridgeResult`` whose `tools` array is ready to pass to
    ///   `LanguageModelSession(tools:)`.
    /// - Throws: ``MCPBridgeError/connectionFailed(_:underlying:)`` if a
    ///   transport-level error occurs, or
    ///   ``MCPBridgeError/schemaConversionFailed(_:underlying:)`` if a tool's
    ///   JSON Schema cannot be converted to a `GenerationSchema`.
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
                MCPLogger.debug(MCPLogger.bridge,
                    "Registered tool '\(wrapper.name)' from \(config.identifier)")
            }
        }

        MCPLogger.info(MCPLogger.bridge,
            "MCPToolBridge ready: \(allTools.count) tool(s) across \(configs.count) server(s)")
        return BridgeResult(tools: allTools, sessionManager: sessionManager)
    }

    /// Convenience overload for connecting to a single MCP server.
    ///
    /// Equivalent to `MCPToolBridge.connect(to: [config])`.
    ///
    /// - Parameter config: A single MCP server configuration.
    /// - Returns: A ``BridgeResult`` with all tools from the server.
    /// - Throws: ``MCPBridgeError`` if the connection or schema conversion fails.
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
/// ## Usage
///
/// Pass `tools` to `LanguageModelSession` and store the `BridgeResult` at the
/// same scope as the session:
///
/// ```swift
/// let bridge = try await MCPToolBridge.connect(to: [...])
/// let session = LanguageModelSession(tools: bridge.tools)
///
/// // bridge must outlive session
/// let response = try await session.respond(to: "...")
/// _ = bridge  // ensure bridge is retained
/// ```
///
/// ## Connection Lifetime
///
/// When this object is deallocated, all MCP connections are closed and any
/// stdio child processes are terminated automatically via `MCPSessionManager`.
///
/// - Important: Do **not** store `tools` separately and release the
///   `BridgeResult` — the tools hold references to `MCP.Client` instances
///   that are owned by this object.
@available(iOS 26.0, macOS 26.0, *)
public final class BridgeResult: Sendable {

    /// Foundation Models–compatible tools discovered from the MCP servers.
    ///
    /// Pass directly to `LanguageModelSession(tools:)`. Each element wraps
    /// one MCP tool as an ``MCPDynamicTool``.
    public let tools: [any FoundationModels.Tool]

    private let sessionManager: MCPSessionManager

    init(tools: [any FoundationModels.Tool], sessionManager: MCPSessionManager) {
        self.tools          = tools
        self.sessionManager = sessionManager
    }

    deinit {
        let manager = sessionManager
        Task { await manager.disconnectAll() }
    }
}

#endif // canImport(FoundationModels)
