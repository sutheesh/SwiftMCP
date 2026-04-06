import Testing
@testable import SwiftMCP
import MCP

@Suite("SchemaConverter")
struct SchemaConverterTests {

    @Test("Empty schema produces empty guide")
    func emptySchemaProducesEmptyGuide() {
        let schema = Value.object(["type": .string("object")])
        let guide = SchemaConverter.buildParameterGuide(from: schema)
        #expect(guide.isEmpty)
    }

    @Test("Single required property is labelled required")
    func singleRequiredProperty() {
        let schema = Value.object([
            "type": .string("object"),
            "properties": .object([
                "city": .object([
                    "type": .string("string"),
                    "description": .string("The city name"),
                ]),
            ]),
            "required": .array([.string("city")]),
        ])
        let guide = SchemaConverter.buildParameterGuide(from: schema)
        #expect(guide.contains("city"))
        #expect(guide.contains("string"))
        #expect(guide.contains("required"))
        #expect(guide.contains("The city name"))
    }

    @Test("Optional property is labelled optional")
    func optionalPropertyLabel() {
        let schema = Value.object([
            "type": .string("object"),
            "properties": .object([
                "units": .object([
                    "type": .string("string"),
                    "description": .string("Temperature units"),
                ]),
            ]),
            "required": .array([]),
        ])
        let guide = SchemaConverter.buildParameterGuide(from: schema)
        #expect(guide.contains("optional"))
    }

    @Test("Enum values appear in guide")
    func enumValuesInGuide() {
        let schema = Value.object([
            "type": .string("object"),
            "properties": .object([
                "units": .object([
                    "type": .string("string"),
                    "enum": .array([.string("metric"), .string("imperial")]),
                ]),
            ]),
            "required": .array([]),
        ])
        let guide = SchemaConverter.buildParameterGuide(from: schema)
        #expect(guide.contains("metric"))
        #expect(guide.contains("imperial"))
    }

    @Test("Description combines tool description and parameter guide")
    func descriptionCombinesFields() {
        let tool = Tool(
            name: "get_weather",
            description: "Get current weather for a location",
            inputSchema: Value.object([
                "type": .string("object"),
                "properties": .object([
                    "city": .object([
                        "type": .string("string"),
                        "description": .string("The city"),
                    ]),
                ]),
                "required": .array([.string("city")]),
            ])
        )
        let description = SchemaConverter.buildToolDescription(for: tool)
        #expect(description.contains("Get current weather"))
        #expect(description.contains("city"))
        #expect(description.contains("required"))
    }

    @Test("Tool with no properties includes no-arguments hint")
    func noPropertiesHint() {
        let tool = Tool(
            name: "ping",
            description: "Ping the server",
            inputSchema: Value.object(["type": .string("object")])
        )
        let description = SchemaConverter.buildToolDescription(for: tool)
        #expect(description.contains("no arguments"))
    }

    @Test("Nil description falls back to tool name")
    func nilDescriptionFallback() {
        let tool = Tool(
            name: "do_thing",
            description: nil,
            inputSchema: Value.object(["type": .string("object")])
        )
        let description = SchemaConverter.buildToolDescription(for: tool)
        #expect(description.contains("do_thing"))
    }
}
