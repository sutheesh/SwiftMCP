# Changelog

All notable changes to SwiftMCP will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] - 2025-06-15

### Added

- **`MCPToolBridge`** — single entry point: `connect(to: [MCPServerConfig]) async throws -> BridgeResult`
- **`BridgeResult`** — holds `tools: [any Tool]` ready for `LanguageModelSession(tools:)`; owns all connections and terminates them on dealloc
- **`MCPServerConfig`** — `.http(URL, headers:)` for remote servers; `.stdio(executablePath:arguments:environment:)` for local subprocesses (macOS only)
- **`MCPDynamicTool`** — bridges a single MCP tool to Apple's `FoundationModels.Tool` protocol using `DynamicGenerationSchema` (no `@Generable` macro required)
- **`MCPToolArguments`** — `ConvertibleFromGeneratedContent` container; extracts the model's output as JSON for forwarding to the MCP server
- **`SchemaConverter`** — converts MCP JSON Schema to `DynamicGenerationSchema`; supports string, integer, number, boolean, array, object, and string enums
- **`ResultConverter`** — converts `[MCP.Tool.Content]` (text, image, audio, resource, resourceLink) to `String` for the model's context
- **`MCPSessionManager`** — actor managing `MCP.Client` connections; handles tool listing with pagination
- **`MCPToolRegistry`** — actor caching discovered tool definitions per server
- **`MCPBridgeError`** — typed errors: `.connectionFailed`, `.schemaConversionFailed`, `.toolCallFailed`
- HTTP transport with custom header injection (Bearer tokens, API keys)
- Stdio transport with child-process lifecycle management (`Process` + `Pipe`)
- Swift 6 strict concurrency throughout (`Sendable`, `actor`)
- Conditional compilation: `#if canImport(FoundationModels)` for Apple Intelligence features, `#if os(macOS)` for stdio/subprocess support
- 16 unit tests covering schema conversion and result conversion

[1.0.0]: https://github.com/YOUR_USERNAME/SwiftMCP/releases/tag/1.0.0
