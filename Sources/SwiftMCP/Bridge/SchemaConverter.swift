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
///
/// ## Supported JSON Schema Features
///
/// | Feature | Handling |
/// |---|---|
/// | `type: "string"` / `"integer"` / `"number"` / `"boolean"` | Mapped to Swift primitive |
/// | `type: "array"` with `items` | `DynamicGenerationSchema(arrayOf:)` |
/// | `type: "object"` with `properties` | Structured schema |
/// | `enum` (string values) | `DynamicGenerationSchema(anyOf:)` enum |
/// | `anyOf` / `oneOf` | First non-null schema used |
/// | `allOf` | Properties merged into a single object schema |
/// | `nullable: true` / `type: ["T","null"]` | Null branch stripped; non-null type used |
/// | `$ref` | **Not supported** — falls back to `String` |
public enum SchemaConverter {

    // MARK: - Text description (always compiled)

    /// Builds the full `description` string for an `MCPDynamicTool`.
    ///
    /// The description is embedded in the tool so the on-device model
    /// can generate the correct argument JSON without seeing the schema directly.
    ///
    /// Example output:
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

    static func extractString(_ value: MCP.Value?) -> String? {
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
    ///
    /// - Throws: If `GenerationSchema(root:dependencies:)` rejects the constructed schema.
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
    ///
    /// Resolution order for a schema node:
    /// 1. Nullable array type (`type: ["T","null"]`) — strip null, use non-null type
    /// 2. `anyOf` / `oneOf` — use first non-null branch
    /// 3. `allOf` — merge all object properties
    /// 4. `type: "string"` with `enum` — string enum
    /// 5. Primitive types: `string`, `integer`, `number`, `boolean`
    /// 6. `type: "array"` — array of item schema
    /// 7. `type: "object"` or untyped — object with `properties`
    /// 8. `$ref` / unknown — fall back to `String`
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    static func buildDynamic(
        schema:       MCP.Value,
        name:         String,
        description:  String?,
        requiredKeys: Set<String>,
        dependencies: inout [DynamicGenerationSchema]
    ) -> DynamicGenerationSchema {
        guard case .object(let dict) = schema else {
            // Scalar / unrecognised — fall back to String
            return DynamicGenerationSchema(type: String.self)
        }

        // ------------------------------------------------------------------
        // 1. Nullable array type: type: ["string", "null"]
        // ------------------------------------------------------------------
        if case .array(let typeArray) = dict["type"] {
            let nonNullTypes = typeArray.compactMap { (v: MCP.Value) -> String? in
                if case .string(let s) = v, s != "null" { return s }
                return nil
            }
            if let first = nonNullTypes.first {
                // Rebuild with the single non-null type and recurse
                var simplified = dict
                simplified["type"] = .string(first)
                return buildDynamic(
                    schema:       .object(simplified),
                    name:         name,
                    description:  description,
                    requiredKeys: requiredKeys,
                    dependencies: &dependencies
                )
            }
            return DynamicGenerationSchema(type: String.self)
        }

        // ------------------------------------------------------------------
        // 2. anyOf / oneOf — use first non-null branch
        // ------------------------------------------------------------------
        for compositeKey in ["anyOf", "oneOf"] {
            if case .array(let branches) = dict[compositeKey] {
                // Filter out null-only branches: {type: "null"}
                let nonNull = branches.filter { branch in
                    if case .object(let d) = branch,
                       case .string(let t) = d["type"], t == "null" { return false }
                    return true
                }
                // String enum: all branches are const strings or single-value enums
                let constStrings = nonNull.compactMap { branch -> String? in
                    if case .object(let d) = branch {
                        if case .string(let s) = d["const"] { return s }
                        if case .string("string") = d["type"],
                           case .array(let e) = d["enum"],
                           e.count == 1, case .string(let s) = e[0] { return s }
                    }
                    return nil
                }
                if constStrings.count == nonNull.count, !constStrings.isEmpty {
                    return DynamicGenerationSchema(name: name, description: description,
                                                   anyOf: constStrings)
                }
                // Otherwise use first non-null branch
                if let first = nonNull.first {
                    MCPLogger.debug(MCPLogger.schema,
                        "anyOf/oneOf for '\(name)': using first of \(nonNull.count) branch(es)")
                    return buildDynamic(
                        schema:       first,
                        name:         name,
                        description:  description,
                        requiredKeys: requiredKeys,
                        dependencies: &dependencies
                    )
                }
                return DynamicGenerationSchema(type: String.self)
            }
        }

        // ------------------------------------------------------------------
        // 3. allOf — merge properties from all sub-schemas
        // ------------------------------------------------------------------
        if case .array(let subSchemas) = dict["allOf"] {
            var mergedProps:     [String: MCP.Value] = [:]
            var mergedRequired:  [MCP.Value] = []
            for sub in subSchemas {
                if case .object(let d) = sub {
                    if case .object(let props) = d["properties"] {
                        mergedProps.merge(props) { _, new in new }
                    }
                    if case .array(let req) = d["required"] {
                        mergedRequired.append(contentsOf: req)
                    }
                }
            }
            if !mergedProps.isEmpty {
                let merged = MCP.Value.object([
                    "type":       .string("object"),
                    "properties": .object(mergedProps),
                    "required":   .array(mergedRequired),
                ])
                MCPLogger.debug(MCPLogger.schema,
                    "allOf for '\(name)': merged \(mergedProps.count) property/ies")
                return buildDynamic(
                    schema:       merged,
                    name:         name,
                    description:  description,
                    requiredKeys: requiredKeys,
                    dependencies: &dependencies
                )
            }
        }

        // ------------------------------------------------------------------
        // 4. $ref — not supported, fall back to String
        // ------------------------------------------------------------------
        if dict["$ref"] != nil {
            MCPLogger.debug(MCPLogger.schema,
                "'\(name)' uses $ref which is not supported — falling back to String")
            return DynamicGenerationSchema(type: String.self)
        }

        let typeStr = extractString(dict["type"])

        // ------------------------------------------------------------------
        // 5. String enum
        // ------------------------------------------------------------------
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

        // ------------------------------------------------------------------
        // 6. Primitive types
        // ------------------------------------------------------------------
        switch typeStr {
        case "string":  return DynamicGenerationSchema(type: String.self)
        case "integer": return DynamicGenerationSchema(type: Int.self)
        case "number":  return DynamicGenerationSchema(type: Double.self)
        case "boolean": return DynamicGenerationSchema(type: Bool.self)

        // ------------------------------------------------------------------
        // 7. Array
        // ------------------------------------------------------------------
        case "array":
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
            return DynamicGenerationSchema(arrayOf: itemDyn)

        // ------------------------------------------------------------------
        // 8. Object (or untyped)
        // ------------------------------------------------------------------
        case "object", .none:
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
                // No properties — treat as an unstructured string passthrough
                return DynamicGenerationSchema(type: String.self)
            }
            return DynamicGenerationSchema(name: name, description: description,
                                           properties: properties)

        default:
            return DynamicGenerationSchema(type: String.self)
        }
    }

    static func extractObject(_ value: MCP.Value) -> [String: MCP.Value]? {
        if case .object(let d) = value { return d }
        return nil
    }

#endif // canImport(FoundationModels)
}
