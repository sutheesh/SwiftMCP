/// SwiftMCP — Bridge between Apple's on-device Foundation Models and the MCP ecosystem.
///
/// Any MCP server becomes instantly available as a tool for `LanguageModelSession`
/// with a single `MCPToolBridge.connect(to:)` call.
///
/// ## Quick Start
///
/// ```swift
/// import SwiftMCP
/// import FoundationModels
///
/// // 1. Connect to MCP servers and discover their tools
/// let bridge = try await MCPToolBridge.connect(to: [
///     .http(URL(string: "https://weather.mcp.server")!),
///     .http(URL(string: "https://stocks.mcp.server")!),
/// ])
///
/// // 2. Pass tools directly to Apple's on-device model
/// let session = LanguageModelSession(tools: bridge.tools)
///
/// // 3. The model can now call any MCP tool automatically
/// let response = try await session.respond(
///     to: "What's the weather in Dallas and should I buy AAPL?"
/// )
/// print(response.content)
///
/// // 4. Keep `bridge` in scope to keep connections alive
/// ```
///
/// ## Architecture
///
/// ```
/// Apple Foundation Models          MCP Ecosystem
/// (on-device, iOS 26+)    ←→      (thousands of servers)
///        ↑                                ↑
///   Tool protocol               MCP servers
///   LanguageModelSession        (weather, files,
///   On-device privacy            stocks, calendar...)
///        └──────── SwiftMCP ────────────┘
/// ```
///
/// ## How It Works
///
/// Apple's `Tool` protocol requires argument types decorated with `@Generable`
/// — a compile-time macro. MCP tools are discovered at runtime, so they can't
/// use compile-time macros. SwiftMCP solves this with `DynamicGenerationSchema`,
/// a public Apple API that builds argument schemas entirely at runtime without
/// any macros. Each `MCPDynamicTool` wraps one MCP tool and conforms to
/// `FoundationModels.Tool` using this runtime schema approach.
///
/// ## Requirements
/// - iOS 26.0+ / macOS 26.0+  (Apple Foundation Models framework)
/// - Xcode 26+
///
/// ## Key Types
/// - ``MCPToolBridge`` — Entry point; connects to servers and vends tools.
/// - ``BridgeResult`` — Holds tools + connection lifetime.
/// - ``MCPServerConfig`` — Server endpoint (HTTP or stdio subprocess).
/// - ``MCPBridgeError`` — Errors from the bridge layer.
