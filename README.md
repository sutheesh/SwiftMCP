# SwiftMCP

**Connect Apple's on-device Foundation Models to the entire MCP ecosystem — any MCP server becomes a tool for Apple Intelligence in 3 lines of code.**

[![Swift 6.2](https://img.shields.io/badge/Swift-6.2-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2018%20%7C%20macOS%2015-blue.svg)](https://developer.apple.com)
[![Foundation Models](https://img.shields.io/badge/Foundation%20Models-iOS%2026%20%7C%20macOS%2026-purple.svg)](https://developer.apple.com/documentation/foundationmodels)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![CI](https://github.com/sutheesh/SwiftMCP/actions/workflows/ci.yml/badge.svg)](https://github.com/sutheesh/SwiftMCP/actions/workflows/ci.yml)

---

## The Problem

Apple's [Foundation Models](https://developer.apple.com/documentation/foundationmodels) framework (iOS 26+) brings a powerful on-device LLM to every iPhone. It supports tool calling — but only through Apple's own `Tool` protocol.

The [Model Context Protocol](https://modelcontextprotocol.io) (MCP) ecosystem has thousands of ready-made servers for weather, stocks, calendars, files, databases, and more — but they speak a completely different language.

**These two worlds are disconnected. SwiftMCP is the bridge.**

```
Apple Foundation Models          MCP Ecosystem
(on-device, iOS 26+)    ←→      (thousands of servers)
       ↑                                ↑
  Tool protocol               Weather, Stocks,
  LanguageModelSession        Files, Calendar,
  On-device privacy           Databases...
       └──────── SwiftMCP ────────────┘
```

---

## Quick Start

```swift
import SwiftMCP
import FoundationModels

// 1. Connect to any MCP server(s) and discover their tools
let bridge = try await MCPToolBridge.connect(to: [
    .http(URL(string: "https://weather.example.com/mcp")!),
    .http(URL(string: "https://stocks.example.com/mcp")!),
])

// 2. Pass tools directly to Apple's on-device model
let session = LanguageModelSession(tools: bridge.tools)

// 3. The model can now call any MCP tool automatically
let response = try await session.respond(
    to: "What's the weather in Dallas and should I buy AAPL today?"
)
print(response.content)

// Keep `bridge` alive for the session duration — it owns the connections
```

That's it. Every tool on every connected MCP server is now available to Apple's on-device AI.

---

## Installation

### Swift Package Manager

Add SwiftMCP to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/sutheesh/SwiftMCP", from: "1.0.0"),
],
targets: [
    .target(
        name: "SwiftMCP",
        dependencies: ["SwiftMCP"]
    ),
]
```

Or add it directly in Xcode: **File → Add Package Dependencies** and enter the repository URL.

### Requirements

| Requirement | Version |
|---|---|
| Swift | 6.2+ |
| Xcode | 26+ (for Foundation Models) |
| iOS | 18+ (compile) / 26+ (Foundation Models at runtime) |
| macOS | 15+ (compile) / 26+ (Foundation Models at runtime) |

> **Note:** The package compiles on iOS 18+ / macOS 15+ for testing and MCP-only usage. Foundation Models features activate at runtime on iOS 26+ / macOS 26+.

---

## Usage

### Connecting to MCP Servers

#### HTTP / SSE (remote servers)

```swift
let bridge = try await MCPToolBridge.connect(to: [
    .http(URL(string: "https://api.example.com/mcp")!),
])
```

With custom headers (for authentication):

```swift
let bridge = try await MCPToolBridge.connect(to: [
    .http(
        URL(string: "https://api.example.com/mcp")!,
        headers: ["Authorization": "Bearer \(apiKey)"]
    ),
])
```

#### Stdio (local subprocess, macOS only)

```swift
let bridge = try await MCPToolBridge.connect(to: [
    .stdio(executablePath: "/usr/local/bin/my-mcp-server"),
])
```

With arguments and environment:

```swift
let bridge = try await MCPToolBridge.connect(to: [
    .stdio(
        executablePath: "/usr/local/bin/filesystem-mcp",
        arguments: ["--root", "/Users/me/Documents"],
        environment: ["LOG_LEVEL": "info"]
    ),
])
```

### Using with LanguageModelSession

```swift
import SwiftMCP
import FoundationModels

@available(iOS 26.0, macOS 26.0, *)
func askWithMCPTools() async throws {
    let bridge = try await MCPToolBridge.connect(to: [
        .http(URL(string: "https://weather.example.com/mcp")!),
    ])

    let session = LanguageModelSession(
        tools: bridge.tools,
        instructions: "You are a helpful assistant with access to real-time data."
    )

    let response = try await session.respond(to: "What's the weather in Tokyo?")
    print(response.content)
}
```

### Discovering Available Tools

```swift
let bridge = try await MCPToolBridge.connect(to: [
    .http(URL(string: "https://myserver.example.com/mcp")!),
])

// Print all discovered tools
for tool in bridge.tools {
    print("Tool: \(tool.name)")
    print("Description: \(tool.description)")
}
```

### Error Handling

```swift
do {
    let bridge = try await MCPToolBridge.connect(to: [
        .http(URL(string: "https://myserver.example.com/mcp")!),
    ])
    // use bridge...
} catch MCPBridgeError.connectionFailed(let server, let error) {
    print("Could not connect to \(server): \(error)")
} catch MCPBridgeError.schemaConversionFailed(let tool, let error) {
    print("Schema error for tool '\(tool)': \(error)")
}
```

---

## How It Works

Apple's `Tool` protocol requires argument types decorated with `@Generable` — a compile-time macro. MCP tools are discovered at runtime, so they can't use compile-time macros.

SwiftMCP solves this with **`DynamicGenerationSchema`** — a public Apple API that builds argument schemas entirely at runtime, without any macros:

```
MCP Tool JSON Schema
        ↓
SchemaConverter.buildGenerationSchema(for:)
        ↓
DynamicGenerationSchema (runtime, no macros)
        ↓
MCPDynamicTool (conforms to FoundationModels.Tool)
        ↓
LanguageModelSession
```

When the model calls a tool:
1. It generates a `GeneratedContent` value shaped by the `DynamicGenerationSchema`
2. `MCPDynamicTool.call(arguments:)` extracts that as JSON via `GeneratedContent.jsonString`
3. The JSON is forwarded to the MCP server via `client.callTool(...)`
4. The MCP response is returned to the model as a `String`

---

## Architecture

```
SwiftMCP/
├── Core/
│   ├── MCPToolBridge.swift        ← Public entry point: connect(to:) → BridgeResult
│   ├── MCPSessionManager.swift    ← Manages MCP.Client connections + pagination
│   └── MCPToolRegistry.swift      ← Caches discovered tool definitions
│
├── Bridge/
│   ├── MCPToFoundationTool.swift  ← MCPDynamicTool + MCPToolArguments
│   ├── SchemaConverter.swift      ← MCP JSON Schema → DynamicGenerationSchema
│   └── ResultConverter.swift      ← [MCP.Tool.Content] → String
│
└── Models/
    └── MCPServerConfig.swift      ← .http(URL) / .stdio(path) + transport factory
```

### Key Types

| Type | Description |
|---|---|
| `MCPToolBridge` | Entry point. Call `connect(to:)` to get a `BridgeResult`. |
| `BridgeResult` | Holds `tools: [any Tool]` + keeps connections alive. Retain it for the session. |
| `MCPServerConfig` | `.http(URL, headers:)` or `.stdio(executablePath:arguments:environment:)` |
| `MCPDynamicTool` | A Foundation Models `Tool` wrapping one MCP tool. |
| `MCPToolArguments` | Argument container conforming to `ConvertibleFromGeneratedContent`. |
| `MCPBridgeError` | Typed errors from connection and schema conversion. |

---

## Connection Lifetime

`BridgeResult` owns the session manager and all open connections. **Keep it alive** for the duration of your `LanguageModelSession`:

```swift
// Store at the right scope — property, not local variable
class MyViewModel: ObservableObject {
    private var bridge: BridgeResult?
    private var session: LanguageModelSession?

    func setup() async throws {
        bridge = try await MCPToolBridge.connect(to: [...])
        session = LanguageModelSession(tools: bridge!.tools)
    }
    // bridge stays alive as long as MyViewModel exists
}
```

When `BridgeResult` is deallocated, all MCP connections are closed and any stdio child processes are terminated automatically.

---

## MCP Server Compatibility

SwiftMCP works with any MCP-compliant server. Some popular ones:

| Server | What it does | Config |
|---|---|---|
| [filesystem](https://github.com/modelcontextprotocol/servers/tree/main/src/filesystem) | Read/write local files | `.stdio(executablePath: "npx", arguments: ["-y", "@modelcontextprotocol/server-filesystem", "/path"])` |
| [fetch](https://github.com/modelcontextprotocol/servers/tree/main/src/fetch) | Fetch web content | `.stdio(executablePath: "uvx", arguments: ["mcp-server-fetch"])` |
| Any HTTP/SSE server | Remote APIs | `.http(URL(string: "https://...")!)` |

---

## Security

### Transport Security

- **HTTP/SSE transport**: SwiftMCP delegates TLS to `URLSession`, which enforces App Transport Security (ATS) by default. All HTTPS endpoints use system certificate validation. If you need certificate pinning, supply a custom `URLSessionDelegate` via a `URLSession` configured before passing the URL.
- **Bearer tokens and API keys**: Pass credentials in `headers:` rather than embedding them in the URL to avoid accidental logging. Never hard-code secrets in source — use `Keychain` or environment variables.
- **Stdio transport**: The child process runs with the same sandbox and entitlements as your app. Only launch executables from trusted, verified paths. Avoid passing unsanitised user input as `arguments` or `environment` values.

### Input Sanitisation

SwiftMCP forwards the JSON string generated by the on-device Foundation Models to the MCP server as-is. The on-device model is trusted to produce well-formed JSON matching the declared schema. If your MCP server performs any server-side actions (file writes, database mutations, shell commands), apply your own validation on the server side — do not rely solely on schema conformance.

### Stdio Subprocess Sandboxing

On macOS, stdio child processes inherit your app's sandbox. If your app has restricted entitlements (e.g. App Sandbox enabled), the subprocess must be a separate sandboxed process or have the appropriate entitlements. SwiftMCP terminates stdio processes on `BridgeResult` dealloc; abnormal app termination may leave orphaned processes — consider registering a signal handler if this matters for your use case.

### Known Limitations

- No built-in OAuth 2.0 flow — Bearer tokens must be obtained and refreshed by the caller.
- No certificate pinning helpers — use a custom `URLSession` if required.
- `$ref` resolution in JSON Schema is not supported; schemas using `$ref` are treated as untyped and fall back to `String`.

---

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) before submitting a pull request.

**Areas where help is appreciated:**
- More test coverage
- Additional transport options
- SwiftUI status component (`MCPToolStatusView`)
- `LanguageModelSession` convenience extensions
- Documentation improvements

---

## License

SwiftMCP is available under the MIT License. See [LICENSE](LICENSE) for details.

---

## Related

- [Apple Foundation Models Documentation](https://developer.apple.com/documentation/foundationmodels)
- [Model Context Protocol](https://modelcontextprotocol.io)
- [MCP Swift SDK](https://github.com/modelcontextprotocol/swift-sdk)
