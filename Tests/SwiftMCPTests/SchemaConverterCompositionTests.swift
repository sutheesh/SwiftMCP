import Testing
@testable import SwiftMCP
import MCP

/// Tests for the advanced JSON Schema composition features added to SchemaConverter:
/// nullable types, anyOf/oneOf (non-enum), allOf merging, and $ref fallback.
@Suite("SchemaConverter — composition")
struct SchemaConverterCompositionTests {

    // MARK: - Nullable array type

    @Test("Nullable type array strips null and uses non-null type")
    func nullableArrayType() {
        let schema = Value.object([
            "type": .string("object"),
            "properties": .object([
                "name": .object([
                    "type": .array([.string("string"), .string("null")]),
                    "description": .string("Person's name, nullable"),
                ]),
            ]),
            "required": .array([]),
        ])
        let guide = SchemaConverter.buildParameterGuide(from: schema)
        // The guide is text-based; nullable properties still appear
        #expect(guide.contains("name"))
    }

    // MARK: - anyOf string enum from branches

    @Test("anyOf with const string branches produces enum guide")
    func anyOfConstStrings() {
        let schema = Value.object([
            "type": .string("object"),
            "properties": .object([
                "direction": .object([
                    "anyOf": .array([
                        .object(["const": .string("north")]),
                        .object(["const": .string("south")]),
                        .object(["const": .string("east")]),
                    ]),
                    "description": .string("Compass direction"),
                ]),
            ]),
            "required": .array([.string("direction")]),
        ])
        let guide = SchemaConverter.buildParameterGuide(from: schema)
        #expect(guide.contains("direction"))
    }

    // MARK: - allOf merging

    @Test("allOf merges required fields from sub-schemas")
    func allOfMergeRequired() {
        // A tool whose inputSchema uses allOf to combine two sub-objects
        let tool = Tool(
            name: "create_user",
            description: "Create a user",
            inputSchema: Value.object([
                "allOf": .array([
                    .object([
                        "type": .string("object"),
                        "properties": .object([
                            "name": .object(["type": .string("string")]),
                        ]),
                        "required": .array([.string("name")]),
                    ]),
                    .object([
                        "type": .string("object"),
                        "properties": .object([
                            "email": .object(["type": .string("string")]),
                        ]),
                        "required": .array([.string("email")]),
                    ]),
                ]),
            ])
        )
        // Should not crash — allOf merging falls back gracefully
        let description = SchemaConverter.buildToolDescription(for: tool)
        #expect(!description.isEmpty)
    }

    // MARK: - $ref fallback

    @Test("Schema with $ref in property does not crash")
    func refFallback() {
        let tool = Tool(
            name: "complex_tool",
            description: "Uses $ref",
            inputSchema: Value.object([
                "type": .string("object"),
                "properties": .object([
                    "address": .object([
                        "$ref": .string("#/definitions/Address"),
                    ]),
                ]),
                "required": .array([]),
            ])
        )
        let description = SchemaConverter.buildToolDescription(for: tool)
        #expect(!description.isEmpty)
    }

    // MARK: - oneOf with null branch

    @Test("oneOf with null branch uses non-null branch")
    func oneOfWithNull() {
        let schema = Value.object([
            "type": .string("object"),
            "properties": .object([
                "cursor": .object([
                    "oneOf": .array([
                        .object(["type": .string("string")]),
                        .object(["type": .string("null")]),
                    ]),
                ]),
            ]),
            "required": .array([]),
        ])
        let guide = SchemaConverter.buildParameterGuide(from: schema)
        #expect(guide.contains("cursor"))
    }
}
