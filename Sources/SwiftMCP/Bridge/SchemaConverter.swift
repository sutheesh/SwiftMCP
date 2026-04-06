import MCP

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Converts MCP JSON Schema (`Value`) into formats needed by the bridge.
///
/// Two outputs:
/// 1. A human-readable `String` description embedded in the tool's `description` property.
/// 2. A `GenerationSchema` (when FoundationModels is available) used by the on-device
///    model to generate structured argument values.
public enum SchemaConverter {

    // MARK: - Text description (always compiled)

    /// Builds the full `description` string for a `MCPDynamicTool`.
    ///
    /// Example:
    /// ```
    /// Get weather for a location.
    /// Arguments:
    ///   • location (string, required) — The city name
    ///   • units (string, optional) — "metric" or "imperial"
    /// ```
    public static func buildToolDescription(for mcpTool: MCP.Tool) -> String {
        let base  = mcpTool.description ?? mcpTool.name
        let guide = buildParameterGuide(from: mcpTool.inputSchema)
        guard !guide.isEmpty else {
            return "\(base). This tool takes no arguments."
        }
        return "\(base)\nArguments:\n\(guide)"
    }

    /// Returns a bullet-point parameter list derived from a JSON Schema `Value`.
    static func buildParameterGuide(from schema: MCP.Value) -> String {
        guard case .object(let schemaDict) = schema else { return "" }

        let required = extractRequiredSet(from: schemaDict["required"])

        guard case .object(let properties) = schemaDict["properties"] else { return "" }

        return properties
            .sorted { $0.key < $1.key }
            .map { name, propSchema in
                "  • " + formatProperty(name: name, schema: propSchema,
                                        isRequired: required.contains(name))
            }
            .joined(separator: "\n")
    }

    // MARK: - Private text helpers

    private static func formatProperty(name: String, schema: MCP.Value, isRequired: Bool) -> String {
        guard case .object(let props) = schema else {
            return "\(name) (\(isRequired ? "required" : "optional"))"
        }
        let type = extractString(props["type"]) ?? "any"
        let desc = extractString(props["description"]) ?? ""
        let req  = isRequired ? "required" : "optional"
        var line = "\(name) (\(type), \(req))"
        if !desc.isEmpty { line += " — \(desc)" }
        if let enumVals = extractEnumValues(from: props["enum"]) { line += " [\(enumVals)]" }
        return line
    }

    private static func extractRequiredSet(from value: MCP.Value?) -> Set<String> {
        guard case .array(let items) = value else { return [] }
        return Set(items.compactMap { if case .string(let s) = $0 { return s }; return nil })
    }

    private static func extractString(_ value: MCP.Value?) -> String? {
        guard case .string(let s) = value else { return nil }
        return s
    }

    private static func extractEnumValues(from value: MCP.Value?) -> String? {
        guard case .array(let items) = value, !items.isEmpty else { return nil }
        let strings = items.compactMap { item -> String? in
            switch item {
            case .string(let s): return "\"\(s)\""
            case .int(let i):    return "\(i)"
            case .double(let d): return "\(d)"
            default:             return nil
            }
        }
        return strings.isEmpty ? nil : strings.joined(separator: ", ")
    }

    // MARK: - GenerationSchema builder (iOS 26 / macOS 26+)

#if canImport(FoundationModels)
    /// Builds a `GenerationSchema` from an MCP tool's `inputSchema` using
    /// `DynamicGenerationSchema` — no `@Generable` macro required.
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    static func buildGenerationSchema(for mcpTool: MCP.Tool) throws -> GenerationSchema {
        var dependencies: [DynamicGenerationSchema] = []
        let root = buildDynamic(
            schema:       mcpTool.inputSchema,
            name:         "Arguments",
            description:  nil,
            requiredKeys: extractRequiredSet(from: extractObject(mcpTool.inputSchema)?["required"]),
            dependencies: &dependencies
        )
        return try GenerationSchema(root: root, dependencies: dependencies)
    }

    /// Recursively converts a JSON Schema `Value` to a `DynamicGenerationSchema`.
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    private static func buildDynamic(
        schema:       MCP.Value,
        name:         String,
        description:  String?,
        requiredKeys: Set<String>,
        dependencies: inout [DynamicGenerationSchema]
    ) -> DynamicGenerationSchema {
        guard case .object(let dict) = schema else {
            // Unknown / untyped — fall back to a plain string
            return DynamicGenerationSchema(type: String.self)
        }

        let typeStr = extractString(dict["type"])

        // String enum
        if typeStr == "string", let enumVals = dict["enum"],
           case .array(let items) = enumVals {
            let choices = items.compactMap { (v: MCP.Value) -> String? in
                if case .string(let s) = v { return s }
                return nil
            }
            if !choices.isEmpty {
                return DynamicGenerationSchema(name: name, description: description, anyOf: choices)
            }
        }

        // Primitive types
        switch typeStr {
        case "string":  return DynamicGenerationSchema(type: String.self)
        case "integer": return DynamicGenerationSchema(type: Int.self)
        case "number":  return DynamicGenerationSchema(type: Double.self)
        case "boolean": return DynamicGenerationSchema(type: Bool.self)
        case "array":
            let itemSchema = dict["items"].flatMap { extractObject($0) }
            let itemDyn: DynamicGenerationSchema
            if let items = dict["items"] {
                itemDyn = buildDynamic(
                    schema:       items,
                    name:         name + "Item",
                    description:  nil,
                    requiredKeys: [],
                    dependencies: &dependencies
                )
            } else {
                itemDyn = DynamicGenerationSchema(type: String.self)
            }
            _ = itemSchema // suppress unused warning
            return DynamicGenerationSchema(arrayOf: itemDyn)
        case "object", .none:
            // Build a structure schema from properties
            let nested = extractRequiredSet(from: dict["required"])
            var properties: [DynamicGenerationSchema.Property] = []

            if case .object(let props) = dict["properties"] {
                for (propName, propSchema) in props.sorted(by: { $0.key < $1.key }) {
                    let propDesc = extractString(extractObject(propSchema)?["description"])
                    let propDyn  = buildDynamic(
                        schema:       propSchema,
                        name:         propName,
                        description:  propDesc,
                        requiredKeys: [],
                        dependencies: &dependencies
                    )
                    properties.append(
                        DynamicGenerationSchema.Property(
                            name:        propName,
                            description: propDesc,
                            schema:      propDyn,
                            isOptional:  !nested.contains(propName)
                        )
                    )
                }
            }

            if properties.isEmpty {
                // No properties — represent as a string passthrough
                return DynamicGenerationSchema(type: String.self)
            }
            return DynamicGenerationSchema(name: name, description: description, properties: properties)
        default:
            return DynamicGenerationSchema(type: String.self)
        }
    }

    private static func extractObject(_ value: MCP.Value) -> [String: MCP.Value]? {
        if case .object(let d) = value { return d }
        return nil
    }

#endif // canImport(FoundationModels)
}
