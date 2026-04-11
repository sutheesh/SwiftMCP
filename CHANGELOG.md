# Changelog

All notable changes to SwiftMCP will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.1.0] - 2026-04-11

### Added

- **`MCPLogger`** — structured `os.Logger`-backed logging with configurable verbosity (`MCPLogger.logLevel = .debug/.info/.error/.off`); all subsystems instrumented (Bridge, Session, Schema, Transport)
- **`ArgumentParser`** — extracted JSON → `[String: MCP.Value]` parsing into a standalone testable type
- **`MCPBridgeError.toolCallFailed`** — new error case; `MCPDynamicTool.call(arguments:)` now returns a graceful `[error] …` string on MCP-level failures instead of throwing, keeping `LanguageModelSession` alive
- **`ResultConverter.toolCallError(tool:error:)`** — internal helper for consistent error string formatting
- **`SchemaConverter`** — expanded JSON Schema support: `anyOf`/`oneOf` (non-null branch selection and const-string enum detection), `allOf` property merging, nullable array types (`type: ["T","null"]`), `$ref` graceful fallback to `String`
- **`MCPSessionManager.fetchAllPages`** — pagination helper extracted as a `static` method for testability
- **Security section** in README — covers TLS, credential handling, stdio sandboxing, input sanitisation, and known limitations
- **Novel contribution note** in README "How It Works" — documents the `DynamicGenerationSchema` approach as the first open-source runtime MCP tool bridge for Apple's on-device Foundation Models
- **Full DocC documentation** on all public types: `MCPToolBridge`, `BridgeResult`, `MCPServerConfig`, `MCPTransportHandle`, `MCPBridgeError`, `MCPDynamicTool`, `MCPToolArguments`, `ResultConverter`, `SchemaConverter`
- **Examples/MCPDemo** — standalone SwiftUI sample app demonstrating end-to-end MCP ↔ Foundation Models integration
- **`.github/workflows/release.yml`** — automated GitHub Release creation on version tags (calls CI, extracts changelog, publishes release notes)

### Changed

- `MCPSessionManager` now uses `MCPLogger` throughout (replaces raw `Logger` calls)
- `MCPServerConfig.makeTransportHandle()` logs transport creation and stdio process PID
- `MCPDynamicTool.parseArguments(_:)` moved to `ArgumentParser.parse(_:)` (internal API change)

### Tests

- 39 new tests — total 55 across 7 suites
- `ArgumentParserTests` (13), `MCPValueTests` (8), `MCPBridgeErrorTests` (5), `PaginationTests` (6), `SchemaConverterCompositionTests` (5) — all passing

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

[1.1.0]: https://github.com/sutheesh/SwiftMCP/compare/1.0.0...1.1.0
[1.0.0]: https://github.com/sutheesh/SwiftMCP/releases/tag/1.0.0
