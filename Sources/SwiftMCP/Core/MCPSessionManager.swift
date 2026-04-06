import MCP
import OSLog

private let logger = Logger(subsystem: "com.swiftmcp", category: "MCPSessionManager")

/// Manages persistent connections to one or more MCP servers.
///
/// Each `MCPServerConfig` maps to a single `MCP.Client` instance.
/// Transport handles (and any associated child processes) are retained here
/// for the full session lifetime.
actor MCPSessionManager {

    private struct Session {
        let client: Client
        let handle: MCPTransportHandle
    }

    private var sessions: [String: Session] = [:]

    // MARK: - Connection Management

    /// Returns a connected `MCP.Client` for `config`, creating one if needed.
    func client(for config: MCPServerConfig) async throws -> Client {
        let key = config.identifier

        if let existing = sessions[key] {
            return existing.client
        }

        let handle = try config.makeTransportHandle()
        let client = Client(name: "SwiftMCP", version: "1.0.0")

        do {
            _ = try await client.connect(transport: handle.transport)
            logger.info("Connected to MCP server: \(key)")
        } catch {
            throw MCPBridgeError.connectionFailed(key, underlying: error)
        }

        sessions[key] = Session(client: client, handle: handle)
        return client
    }

    /// Disconnects from the server identified by `config` and removes the session.
    func disconnect(from config: MCPServerConfig) async {
        let key = config.identifier
        guard let session = sessions.removeValue(forKey: key) else { return }
        await session.client.disconnect()
        logger.info("Disconnected from MCP server: \(key)")
        // `session.handle` is released here, terminating any child process.
    }

    /// Disconnects from all managed servers.
    func disconnectAll() async {
        for (key, session) in sessions {
            await session.client.disconnect()
            logger.info("Disconnected from MCP server: \(key)")
        }
        sessions.removeAll()
    }

    // MARK: - Tool Discovery

    /// Lists all tools available on the server at `config`, following pagination.
    func listTools(for config: MCPServerConfig) async throws -> [MCP.Tool] {
        let client = try await self.client(for: config)
        var allTools: [MCP.Tool] = []
        var cursor: String? = nil

        repeat {
            let page = try await client.listTools(cursor: cursor)
            allTools.append(contentsOf: page.tools)
            cursor = page.nextCursor
        } while cursor != nil

        logger.debug("Discovered \(allTools.count) tool(s) on \(config.identifier)")
        return allTools
    }
}
