import Testing
@testable import SwiftMCP
import MCP
import Foundation

@Suite("MCP.Value(anyValue:)")
struct MCPValueTests {

    @Test("NSNull maps to .null")
    func nullMapping() throws {
        let v = try MCP.Value(anyValue: NSNull())
        #expect(v == .null)
    }

    @Test("Bool maps to .bool")
    func boolMapping() throws {
        #expect(try MCP.Value(anyValue: true)  == .bool(true))
        #expect(try MCP.Value(anyValue: false) == .bool(false))
    }

    @Test("Int maps to .int")
    func intMapping() throws {
        let v = try MCP.Value(anyValue: 42)
        #expect(v == .int(42))
    }

    @Test("Double maps to .double")
    func doubleMapping() throws {
        let v = try MCP.Value(anyValue: 3.14)
        #expect(v == .double(3.14))
    }

    @Test("String maps to .string")
    func stringMapping() throws {
        let v = try MCP.Value(anyValue: "hello")
        #expect(v == .string("hello"))
    }

    @Test("Array is recursively converted")
    func arrayMapping() throws {
        let v = try MCP.Value(anyValue: [1, "two", true] as [Any])
        guard case .array(let items) = v else {
            Issue.record("Expected .array")
            return
        }
        #expect(items.count == 3)
        #expect(items[0] == .int(1))
        #expect(items[1] == .string("two"))
        #expect(items[2] == .bool(true))
    }

    @Test("Dictionary is recursively converted")
    func dictionaryMapping() throws {
        let v = try MCP.Value(anyValue: ["key": "value", "num": 7] as [String: Any])
        guard case .object(let dict) = v else {
            Issue.record("Expected .object")
            return
        }
        #expect(dict["key"] == .string("value"))
        #expect(dict["num"] == .int(7))
    }

    @Test("Nested object is recursively converted")
    func nestedObjectMapping() throws {
        let raw: [String: Any] = ["inner": ["x": 1] as [String: Any]]
        let v = try MCP.Value(anyValue: raw)
        guard case .object(let outer) = v,
              case .object(let inner) = outer["inner"] else {
            Issue.record("Expected nested .object")
            return
        }
        #expect(inner["x"] == .int(1))
    }

    @Test("Unknown type coerced to string")
    func unknownTypeCoercion() throws {
        struct Foo {}
        let v = try MCP.Value(anyValue: Foo())
        if case .string(let s) = v {
            #expect(!s.isEmpty)
        } else {
            Issue.record("Expected .string coercion for unknown type")
        }
    }
}
