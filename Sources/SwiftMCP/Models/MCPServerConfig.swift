import Foundation
import System
import MCP

/// Configuration for connecting to an MCP server.
public enum MCPServerConfig: Sendable {
    /// Remote MCP server reachable via HTTP/SSE transport.
    case http(URL, headers: [String: String] = [:])

#if os(macOS)
    /// Local MCP server running as a child process communicating over stdio.
    ///
    /// SwiftMCP launches the process, wires up its stdin/stdout to a
    /// `StdioTransport`, and keeps the process alive for the connection lifetime.
    ///
    /// - Note: Available on macOS only (`Process` is not available on iOS).
    case stdio(executablePath: String, arguments: [String] = [], environment: [String: String] = [:])
#endif

    /// A human-readable identifier used for logging and error messages.
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
    /// Creates the appropriate MCP transport and — for stdio servers — starts
    /// the child process. Callers must retain the returned `MCPTransportHandle`
    /// for the duration of the session to keep the connection alive.
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

/// Bundles a transport with an optional child process so both stay alive together.
public final class MCPTransportHandle: @unchecked Sendable {
    public let transport: any Transport

#if os(macOS)
    /// Retaining this keeps the subprocess alive.
    private let process: Process?

    init(transport: any Transport, process: Process? = nil) {
        self.transport = transport
        self.process   = process
    }

    deinit {
        process?.terminate()
    }
#else
    init(transport: any Transport) {
        self.transport = transport
    }
#endif
}
