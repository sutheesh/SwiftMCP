import MCP

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
    ///
    /// Subsequent calls with the same `config` return the cached client.
    func client(for config: MCPServerConfig) async throws -> Client {
        let key = config.identifier

        if let existing = sessions[key] {
            MCPLogger.debug(MCPLogger.session, "Reusing existing connection for \(key)")
            return existing.client
        }

        MCPLogger.info(MCPLogger.session, "Connecting to MCP server: \(key)")
        let handle = try config.makeTransportHandle()
        let client = Client(name: "SwiftMCP", version: "1.0.0")

        do {
            _ = try await client.connect(transport: handle.transport)
            MCPLogger.info(MCPLogger.session, "Connected to MCP server: \(key)")
        } catch {
            MCPLogger.error(MCPLogger.session, "Connection failed for \(key): \(error)")
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
        MCPLogger.info(MCPLogger.session, "Disconnected from MCP server: \(key)")
        // `session.handle` is released here, terminating any child process.
    }

    /// Disconnects from all managed servers.
    func disconnectAll() async {
        for (key, session) in sessions {
            await session.client.disconnect()
            MCPLogger.info(MCPLogger.session, "Disconnected from MCP server: \(key)")
        }
        sessions.removeAll()
    }

    // MARK: - Tool Discovery

    /// Lists all tools available on the server at `config`, following pagination.
    func listTools(for config: MCPServerConfig) async throws -> [MCP.Tool] {
        let client = try await self.client(for: config)

        let tools = try await MCPSessionManager.fetchAllPages { cursor in
            let page = try await client.listTools(cursor: cursor)
            MCPLogger.debug(MCPLogger.session,
                "Page for \(config.identifier): \(page.tools.count) tool(s), nextCursor=\(page.nextCursor ?? "nil")")
            return (items: page.tools, nextCursor: page.nextCursor)
        }

        MCPLogger.info(MCPLogger.session,
            "Discovered \(tools.count) tool(s) on \(config.identifier)")
        return tools
    }

    // MARK: - Pagination helper (internal for testability)

    /// Fetches all pages from a paginated source using a cursor-based `fetch` closure.
    ///
    /// Stops when `fetch` returns a `nil` `nextCursor`.
    ///
    /// - Parameter fetch: Called with the current cursor (`nil` for the first page).
    ///   Returns `(items:, nextCursor:)`.
    static func fetchAllPages<T>(
        fetch: (String?) async throws -> (items: [T], nextCursor: String?)
    ) async throws -> [T] {
        var all: [T] = []
        var cursor: String? = nil
        repeat {
            let page = try await fetch(cursor)
            all.append(contentsOf: page.items)
            cursor = page.nextCursor
        } while cursor != nil
        return all
    }
}
