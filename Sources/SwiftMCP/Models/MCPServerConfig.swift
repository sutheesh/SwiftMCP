import Foundation
import System
import MCP

/// Configuration for connecting to an MCP server.
///
/// Use one of the two cases to describe your server:
///
/// ```swift
/// // Remote HTTP/SSE server (iOS + macOS)
/// let remote = MCPServerConfig.http(
///     URL(string: "https://api.example.com/mcp")!,
///     headers: ["Authorization": "Bearer \(token)"]
/// )
///
/// // Local subprocess over stdio (macOS only)
/// let local = MCPServerConfig.stdio(
///     executablePath: "/usr/local/bin/my-mcp-server",
///     arguments: ["--root", "/tmp"],
///     environment: ["LOG_LEVEL": "info"]
/// )
/// ```
///
/// Pass one or more configs to ``MCPToolBridge/connect(to:)``.
public enum MCPServerConfig: Sendable {

    /// Remote MCP server reachable via HTTP/SSE transport.
    ///
    /// - Parameters:
    ///   - url: The base URL of the MCP endpoint (e.g. `https://api.example.com/mcp`).
    ///   - headers: Additional HTTP headers injected into every request.
    ///     Use this for `Authorization: Bearer <token>` or API-key headers.
    ///     Defaults to empty.
    case http(URL, headers: [String: String] = [:])

#if os(macOS)
    /// Local MCP server running as a child process communicating over stdio.
    ///
    /// SwiftMCP launches the process, wires up its stdin/stdout to a
    /// `StdioTransport`, and keeps the process alive for the connection lifetime.
    /// The process is terminated when the ``MCPTransportHandle`` is deallocated
    /// (i.e. when the ``BridgeResult`` goes out of scope).
    ///
    /// - Parameters:
    ///   - executablePath: Absolute path to the server executable.
    ///   - arguments: Command-line arguments passed to the executable. Defaults to `[]`.
    ///   - environment: Additional environment variables merged with the current process
    ///     environment. Defaults to `[:]`.
    ///
    /// - Note: Available on macOS only — `Process` is not available on iOS.
    case stdio(executablePath: String, arguments: [String] = [], environment: [String: String] = [:])
#endif

    /// A human-readable identifier used in log messages and error descriptions.
    ///
    /// For `.http`, this is the absolute URL string.
    /// For `.stdio`, this is the executable path.
    public var identifier: String {
        switch self {
        case .http(let url, _):
            return url.absoluteString
#if os(macOS)
        case .stdio(let path, _, _):
            return path
#endif
        }
    }
}

// MARK: - Transport Factory

extension MCPServerConfig {
    /// Creates the appropriate MCP transport for this configuration and — for
    /// stdio servers — launches the child process.
    ///
    /// Callers must retain the returned ``MCPTransportHandle`` for the duration
    /// of the session to keep the connection alive.
    ///
    /// - Throws: `MCPBridgeError.connectionFailed` if the stdio process cannot
    ///   be launched, or an `HTTPClientTransport` error for HTTP servers.
    func makeTransportHandle() throws -> MCPTransportHandle {
        switch self {
        case .http(let url, let headers):
            let transport = HTTPClientTransport(
                endpoint: url,
                configuration: .default,
                requestModifier: { request in
                    var modified = request
                    for (key, value) in headers {
                        modified.setValue(value, forHTTPHeaderField: key)
                    }
                    return modified
                }
            )
            MCPLogger.debug(MCPLogger.transport, "Created HTTP transport for \(url)")
            return MCPTransportHandle(transport: transport)

#if os(macOS)
        case .stdio(let executablePath, let arguments, let environment):
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments

            var env = ProcessInfo.processInfo.environment
            env.merge(environment) { _, new in new }
            process.environment = env

            let stdinPipe  = Pipe()
            let stdoutPipe = Pipe()
            process.standardInput  = stdinPipe
            process.standardOutput = stdoutPipe
            process.standardError  = FileHandle.standardError

            try process.run()
            MCPLogger.debug(MCPLogger.transport,
                "Launched stdio process: \(executablePath) (pid \(process.processIdentifier))")

            let transport = StdioTransport(
                input:  FileDescriptor(rawValue: stdoutPipe.fileHandleForReading.fileDescriptor),
                output: FileDescriptor(rawValue: stdinPipe.fileHandleForWriting.fileDescriptor)
            )
            return MCPTransportHandle(transport: transport, process: process)
#endif
        }
    }
}

// MARK: - Transport Handle

/// Bundles an MCP transport with an optional child process so both stay alive together.
///
/// Retain this object for the duration of a session. When it is deallocated:
/// - The transport is released.
/// - On macOS, any associated child process is sent `SIGTERM`.
///
/// You do not normally need to interact with this type directly —
/// ``MCPSessionManager`` manages it internally.
public final class MCPTransportHandle: @unchecked Sendable {

    /// The underlying MCP transport (HTTP or stdio).
    public let transport: any Transport

#if os(macOS)
    /// Retaining this keeps the subprocess alive.
    private let process: Process?

    init(transport: any Transport, process: Process? = nil) {
        self.transport = transport
        self.process   = process
    }

    deinit {
        if let process {
            MCPLogger.debug(MCPLogger.transport,
                "Terminating stdio process pid \(process.processIdentifier)")
            process.terminate()
        }
    }
#else
    init(transport: any Transport) {
        self.transport = transport
    }
#endif
}
