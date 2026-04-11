import Testing
@testable import SwiftMCP
import MCP

@Suite("MCPSessionManager.fetchAllPages")
struct PaginationTests {

    @Test("Single page with no nextCursor returns all items")
    func singlePage() async throws {
        let result = try await MCPSessionManager.fetchAllPages { _ in
            (items: ["a", "b", "c"], nextCursor: nil)
        }
        #expect(result == ["a", "b", "c"])
    }

    @Test("Two pages are concatenated")
    func twoPages() async throws {
        var callCount = 0
        let result = try await MCPSessionManager.fetchAllPages { cursor -> (items: [String], nextCursor: String?) in
            callCount += 1
            if cursor == nil {
                return (items: ["a", "b"], nextCursor: "page2")
            } else {
                return (items: ["c", "d"], nextCursor: nil)
            }
        }
        #expect(result == ["a", "b", "c", "d"])
        #expect(callCount == 2)
    }

    @Test("Three pages are all fetched")
    func threePages() async throws {
        var callCount = 0
        let pages: [[String]] = [["x"], ["y"], ["z"]]
        let cursors: [String?] = ["p2", "p3", nil]

        let result = try await MCPSessionManager.fetchAllPages { _ -> (items: [String], nextCursor: String?) in
            let i = callCount
            callCount += 1
            return (items: pages[i], nextCursor: cursors[i])
        }
        #expect(result == ["x", "y", "z"])
        #expect(callCount == 3)
    }

    @Test("Empty page with no cursor returns empty array")
    func emptyPage() async throws {
        let result: [String] = try await MCPSessionManager.fetchAllPages { _ in
            (items: [], nextCursor: nil)
        }
        #expect(result.isEmpty)
    }

    @Test("Thrown error propagates out of fetchAllPages")
    func errorPropagation() async {
        struct FetchError: Error {}
        await #expect(throws: FetchError.self) {
            try await MCPSessionManager.fetchAllPages { _ -> (items: [String], nextCursor: String?) in
                throw FetchError()
            }
        }
    }

    @Test("Correct cursor is passed to each fetch call")
    func cursorPassthrough() async throws {
        var receivedCursors: [String?] = []
        _ = try await MCPSessionManager.fetchAllPages { cursor -> (items: [Int], nextCursor: String?) in
            receivedCursors.append(cursor)
            let next: String? = cursor == nil ? "next" : nil
            return (items: [1], nextCursor: next)
        }
        #expect(receivedCursors.count == 2)
        #expect(receivedCursors[0] == nil)
        #expect(receivedCursors[1] == "next")
    }
}
