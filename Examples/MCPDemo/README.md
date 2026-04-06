# MCPDemo

A minimal SwiftUI chat app that demonstrates SwiftMCP — connecting Apple's on-device Foundation Models to an MCP server.

## Setup

1. Open Xcode and create a new **iOS App** project named `MCPDemo` in this folder.
2. Add SwiftMCP via **File → Add Package Dependencies**:
   - Local: point to the repo root (`../../`)
   - Or remote: `https://github.com/sutheesh/SwiftMCP`
3. Copy the three Swift files from this folder into the project:
   - `MCPDemoApp.swift`
   - `ContentView.swift`
   - `MCPViewModel.swift`
4. Run on an iPhone or simulator with **iOS 26+**.

## Usage

1. Tap the server icon (top-right) and enter your MCP server URL.
2. Tap **Connect** — the status banner shows how many tools were discovered.
3. Type any question and send — the on-device model will call MCP tools automatically.

## Requirements

| | Version |
|---|---|
| iOS | 26.0+ (Foundation Models) |
| Xcode | 26+ |
| SwiftMCP | 1.0.0+ |
