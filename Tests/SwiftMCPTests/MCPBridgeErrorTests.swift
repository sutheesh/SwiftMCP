import Testing
@testable import SwiftMCP
import MCP
import Foundation

@Suite("MCPBridgeError")
struct MCPBridgeErrorTests {

    struct FakeError: Error, LocalizedError {
        let errorDescription: String? = "underlying failure"
    }

    @Test("invalidArgumentsJSON contains detail")
    func invalidArgumentsJSON() {
        let error = MCPBridgeError.invalidArgumentsJSON("top-level must be object")
        let desc = error.errorDescription ?? ""
        #expect(desc.contains("top-level must be object"))
    }

    @Test("connectionFailed contains server name and underlying error")
    func connectionFailed() {
        let error = MCPBridgeError.connectionFailed("https://api.example.com/mcp",
                                                    underlying: FakeError())
        let desc = error.errorDescription ?? ""
        #expect(desc.contains("api.example.com"))
        #expect(desc.contains("underlying failure"))
    }

    @Test("schemaConversionFailed contains tool name and underlying error")
    func schemaConversionFailed() {
        let error = MCPBridgeError.schemaConversionFailed("get_weather", underlying: FakeError())
        let desc = error.errorDescription ?? ""
        #expect(desc.contains("get_weather"))
        #expect(desc.contains("underlying failure"))
    }

    @Test("toolCallFailed contains tool name and underlying error")
    func toolCallFailed() {
        let error = MCPBridgeError.toolCallFailed("fetch_stock", underlying: FakeError())
        let desc = error.errorDescription ?? ""
        #expect(desc.contains("fetch_stock"))
        #expect(desc.contains("underlying failure"))
    }

    @Test("MCPBridgeError conforms to Error")
    func conformsToError() {
        let error: any Error = MCPBridgeError.invalidArgumentsJSON("x")
        #expect(error is MCPBridgeError)
    }
}
