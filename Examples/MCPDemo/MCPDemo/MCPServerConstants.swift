import Foundation

/// All MCP server endpoints used by the demo app.
///
/// Swap these out for your own servers before running.
enum MCPServer {

    // MARK: - Remote HTTP servers

    /// General-purpose weather data server.
    static let weather = "https://weather.example.com/mcp"

    /// Stock market and financial data server.
    static let stocks = "https://stocks.example.com/mcp"

    /// Calendar and scheduling server.
    static let calendar = "https://calendar.example.com/mcp"

    // MARK: - Default

    /// The server shown in the UI on first launch.
    static let `default` = weather
}
