import OSLog

/// Controls SwiftMCP's structured log output.
///
/// Set `MCPLogger.logLevel` before calling `MCPToolBridge.connect(to:)`:
///
/// ```swift
/// MCPLogger.logLevel = .debug   // verbose — connection details, tool registrations
/// MCPLogger.logLevel = .info    // default — connections and tool counts
/// MCPLogger.logLevel = .error   // errors only
/// MCPLogger.logLevel = .off     // completely silent
/// ```
///
/// SwiftMCP uses `os.Logger` internally, so logs are also visible in
/// Instruments and the Console app filtered by subsystem `com.swiftmcp`.
public enum MCPLogger {

    // MARK: - Log level

    /// Minimum severity level to emit. Default: `.info`.
    ///
    /// Although this is shared mutable state, it is intended to be set once
    /// at app startup before any logging occurs. Swift 6 concurrency checks are
    /// suppressed here via `nonisolated(unsafe)`.
    public nonisolated(unsafe) static var logLevel: MCPLogLevel = .info

    // MARK: - Category loggers (internal)

    static let bridge    = Logger(subsystem: "com.swiftmcp", category: "Bridge")
    static let session   = Logger(subsystem: "com.swiftmcp", category: "Session")
    static let schema    = Logger(subsystem: "com.swiftmcp", category: "Schema")
    static let transport = Logger(subsystem: "com.swiftmcp", category: "Transport")

    // MARK: - Emit helpers

    static func debug(_ logger: Logger, _ message: @autoclosure () -> String) {
        guard logLevel >= .debug else { return }
        let msg = message()
        logger.debug("\(msg, privacy: .public)")
    }

    static func info(_ logger: Logger, _ message: @autoclosure () -> String) {
        guard logLevel >= .info else { return }
        let msg = message()
        logger.info("\(msg, privacy: .public)")
    }

    static func error(_ logger: Logger, _ message: @autoclosure () -> String) {
        guard logLevel >= .error else { return }
        let msg = message()
        logger.error("\(msg, privacy: .public)")
    }
}

// MARK: - Log Level

/// Severity levels for `MCPLogger`.
public enum MCPLogLevel: Int, Sendable, Comparable {
    /// No log output.
    case off   = 0
    /// Errors only.
    case error = 1
    /// Connection lifecycle and tool counts (default).
    case info  = 2
    /// Full detail: pagination, tool registration, argument parsing.
    case debug = 3

    public static func < (lhs: MCPLogLevel, rhs: MCPLogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
