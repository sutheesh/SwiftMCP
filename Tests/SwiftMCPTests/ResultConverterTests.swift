import Testing
@testable import SwiftMCP
import MCP

@Suite("ResultConverter")
struct ResultConverterTests {

    @Test("Text content returned as-is")
    func textContent() {
        let content: [Tool.Content] = [.text(text: "72°F, Sunny", annotations: nil, _meta: nil)]
        let result = ResultConverter.string(from: content, isError: nil)
        #expect(result.contains("72°F"))
    }

    @Test("Multiple text blocks joined with newline")
    func multipleTextBlocks() {
        let content: [Tool.Content] = [
            .text(text: "Line 1", annotations: nil, _meta: nil),
            .text(text: "Line 2", annotations: nil, _meta: nil),
        ]
        let result = ResultConverter.string(from: content, isError: nil)
        #expect(result.contains("Line 1"))
        #expect(result.contains("Line 2"))
    }

    @Test("Empty content returns placeholder")
    func emptyContent() {
        let result = ResultConverter.string(from: [], isError: nil)
        #expect(result.contains("no content"))
    }

    @Test("isError true prepends error tag")
    func errorFlag() {
        let content: [Tool.Content] = [.text(text: "Not found", annotations: nil, _meta: nil)]
        let result = ResultConverter.string(from: content, isError: true)
        #expect(result.hasPrefix("[error]"))
    }

    @Test("isError false does not prepend error tag")
    func nonErrorFlag() {
        let content: [Tool.Content] = [.text(text: "OK", annotations: nil, _meta: nil)]
        let result = ResultConverter.string(from: content, isError: false)
        #expect(!result.hasPrefix("[error]"))
    }

    @Test("isError nil does not prepend error tag")
    func nilErrorFlag() {
        let content: [Tool.Content] = [.text(text: "OK", annotations: nil, _meta: nil)]
        let result = ResultConverter.string(from: content, isError: nil)
        #expect(!result.hasPrefix("[error]"))
    }

    @Test("Image content returns MIME-type placeholder")
    func imageContent() {
        let content: [Tool.Content] = [
            .image(data: "data", mimeType: "image/png", annotations: nil, _meta: nil),
        ]
        let result = ResultConverter.string(from: content, isError: nil)
        #expect(result.contains("image/png"))
    }

    @Test("Resource with embedded text returns that text")
    func resourceWithText() {
        let resource = Resource.Content.text("Hello world", uri: "file://readme.md", mimeType: "text/plain")
        let result = ResultConverter.string(from: [.resource(resource: resource)], isError: nil)
        #expect(result.contains("Hello world"))
    }

@Test("Resource link returns name and URI")
    func resourceLink() {
        let content: [Tool.Content] = [
            .resourceLink(
                uri: "https://example.com/doc", name: "Documentation",
                title: nil, description: nil, mimeType: nil, annotations: nil
            ),
        ]
        let result = ResultConverter.string(from: content, isError: nil)
        #expect(result.contains("Documentation"))
        #expect(result.contains("https://example.com/doc"))
    }
}
