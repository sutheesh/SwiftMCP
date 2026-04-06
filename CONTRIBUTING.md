# Contributing to SwiftMCP

Thank you for your interest in contributing! This document covers everything you need to get started.

## What We're Building

SwiftMCP bridges Apple's Foundation Models framework (iOS 26 on-device AI) with the MCP ecosystem. Contributions that expand that bridge — better tool support, more transport options, better developer ergonomics — are most welcome.

## Getting Started

### Prerequisites

- Xcode 26+ (for Foundation Models framework and Swift 6.2)
- macOS 15+ development machine
- Familiarity with Swift concurrency (async/await, actors)

### Setting Up

```bash
git clone https://github.com/sutheesh/SwiftMCP.git
cd SwiftMCP
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

All 16 tests should pass before you start making changes.

## How to Contribute

### Reporting Bugs

Open a GitHub Issue with:
- A minimal reproduction case
- The Xcode / Swift version you're using
- The MCP server you're connecting to (if relevant)
- Full error output

### Suggesting Features

Open a GitHub Issue tagged `enhancement` describing:
- The use case you're trying to solve
- How you'd expect the API to look

### Submitting a Pull Request

1. Fork the repo and create a branch: `git checkout -b feature/my-feature`
2. Write your code following the style guidelines below
3. Add or update tests for any behaviour changes
4. Ensure `swift build` and `swift test` pass
5. Open a PR with a clear description of what and why

## Code Style

- **Swift 6 strict concurrency** — all types must be `Sendable` where required; use `actor` for shared mutable state
- **No force unwraps** in library code — use `throws`, `guard`, or optionals
- **No third-party dependencies** beyond the MCP Swift SDK — keep the dependency tree minimal
- **File structure mirrors the module structure** — Core, Bridge, Models
- **`#if canImport(FoundationModels)` and `#if os(macOS)`** guard platform-specific code
- Comments explain *why*, not *what*

## Project Structure

```
Sources/SwiftMCP/
├── Core/           ← Public API surface (MCPToolBridge, MCPSessionManager)
├── Bridge/         ← Foundation Models integration (MCPDynamicTool, converters)
└── Models/         ← Value types (MCPServerConfig, MCPTransportHandle)

Tests/SwiftMCPTests/
├── SchemaConverterTests.swift
└── ResultConverterTests.swift
```

## Roadmap — Good First Issues

| Area | Description |
|---|---|
| Tests | Integration tests against a local stdio MCP server |
| SwiftUI | `MCPToolStatusView` — shows connected servers and available tools |
| Extensions | `LanguageModelSession.init(mcpServers:)` convenience initializer |
| Transports | OAuth / Bearer token helpers for HTTP servers |
| Docs | DocC documentation for all public types |

## Running Tests

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

Tests that require Foundation Models (iOS 26 runtime) are excluded from the test suite — they require a device or simulator running iOS 26.

## Versioning

SwiftMCP follows [Semantic Versioning](https://semver.org):
- **Patch** (1.0.x) — bug fixes, no API changes
- **Minor** (1.x.0) — new features, backwards compatible
- **Major** (x.0.0) — breaking API changes

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
