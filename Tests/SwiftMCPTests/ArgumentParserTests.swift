import Testing
@testable import SwiftMCP
import MCP

@Suite("ArgumentParser")
struct ArgumentParserTests {

    // MARK: - Empty / trivial inputs

    @Test("Empty string returns empty dict")
    func emptyString() throws {
        let result = try ArgumentParser.parse("")
        #expect(result.isEmpty)
    }

    @Test("Whitespace-only string returns empty dict")
    func whitespaceOnly() throws {
        let result = try ArgumentParser.parse("   \n  ")
        #expect(result.isEmpty)
    }

    @Test("Empty JSON object returns empty dict")
    func emptyObject() throws {
        let result = try ArgumentParser.parse("{}")
        #expect(result.isEmpty)
    }

    @Test("null string returns empty dict")
    func nullString() throws {
        let result = try ArgumentParser.parse("null")
        #expect(result.isEmpty)
    }

    // MARK: - Valid inputs

    @Test("Single string argument parsed correctly")
    func singleStringArg() throws {
        let result = try ArgumentParser.parse(#"{"city":"Dallas"}"#)
        #expect(result["city"] == .string("Dallas"))
    }

    @Test("Integer argument parsed correctly")
    func intArg() throws {
        let result = try ArgumentParser.parse(#"{"count":42}"#)
        #expect(result["count"] == .int(42))
    }

    @Test("Boolean argument parsed correctly")
    func boolArg() throws {
        let result = try ArgumentParser.parse(#"{"verbose":true}"#)
        #expect(result["verbose"] == .bool(true))
    }

    @Test("Null argument parsed correctly")
    func nullArg() throws {
        let result = try ArgumentParser.parse(#"{"cursor":null}"#)
        #expect(result["cursor"] == .null)
    }

    @Test("Multiple arguments parsed correctly")
    func multipleArgs() throws {
        let result = try ArgumentParser.parse(#"{"city":"Tokyo","units":"metric"}"#)
        #expect(result["city"]  == .string("Tokyo"))
        #expect(result["units"] == .string("metric"))
    }

    @Test("Nested object parsed correctly")
    func nestedObject() throws {
        let result = try ArgumentParser.parse(#"{"filter":{"active":true}}"#)
        guard case .object(let inner) = result["filter"] else {
            Issue.record("Expected nested object")
            return
        }
        #expect(inner["active"] == .bool(true))
    }

    @Test("Array argument parsed correctly")
    func arrayArg() throws {
        let result = try ArgumentParser.parse(#"{"tags":["swift","ios"]}"#)
        guard case .array(let items) = result["tags"] else {
            Issue.record("Expected array")
            return
        }
        #expect(items.count == 2)
        #expect(items[0] == .string("swift"))
    }

    // MARK: - Error cases

    @Test("Invalid JSON throws some error")
    func invalidJSON() {
        // JSONSerialization throws NSError for malformed input;
        // MCPBridgeError.invalidArgumentsJSON is thrown for valid JSON with wrong shape.
        #expect(throws: (any Error).self) {
            try ArgumentParser.parse("not json at all")
        }
    }

    @Test("JSON array at top level throws invalidArgumentsJSON")
    func topLevelArrayThrows() {
        #expect(throws: MCPBridgeError.self) {
            try ArgumentParser.parse(#"["a","b"]"#)
        }
    }

    @Test("JSON string at top level throws some error")
    func topLevelStringThrows() {
        // A bare JSON string is rejected either by JSONSerialization (not an object/array
        // without .fragmentsAllowed) or by our type check.
        #expect(throws: (any Error).self) {
            try ArgumentParser.parse(#""just a string""#)
        }
    }
}
