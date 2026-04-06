import SwiftUI
import SwiftMCP

#if canImport(FoundationModels)
import FoundationModels
#endif

@MainActor
@Observable
final class MCPViewModel {

    enum State {
        case idle
        case connecting
        case ready(serverName: String, toolCount: Int)
        case thinking
        case error(String)
    }

    var state: State = .idle
    var messages: [Message] = []
    var inputText: String = ""

    // Keep bridge alive for the session duration
    private var bridge: BridgeResult?

    #if canImport(FoundationModels)
    private var session: LanguageModelSession?
    #endif

    // MARK: - Connect

    /// Connect to an MCP server and set up the LanguageModelSession.
    /// Swap in any MCP server URL or stdio config you like.
    func connect(to serverURL: String) async {
        state = .connecting
        bridge = nil

        #if canImport(FoundationModels)
        guard #available(iOS 26.0, macOS 26.0, *) else {
            state = .error("Foundation Models requires iOS 26 / macOS 26.")
            return
        }

        guard let url = URL(string: serverURL) else {
            state = .error("Invalid server URL.")
            return
        }

        do {
            bridge = try await MCPToolBridge.connect(to: [.http(url)])

            let tools = bridge!.tools
            session = LanguageModelSession(
                tools: tools,
                instructions: "You are a helpful assistant. Use the available tools to answer questions accurately."
            )
            state = .ready(serverName: url.host ?? serverURL, toolCount: tools.count)
        } catch {
            state = .error(error.localizedDescription)
        }
        #else
        state = .error("FoundationModels is not available on this platform/OS version.")
        #endif
    }

    // MARK: - Send

    func send() async {
        let prompt = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }

        messages.append(Message(role: .user, text: prompt))
        inputText = ""
        state = .thinking

        #if canImport(FoundationModels)
        guard #available(iOS 26.0, macOS 26.0, *), let session else {
            messages.append(Message(role: .assistant, text: "Not connected. Tap Connect first."))
            state = .idle
            return
        }

        do {
            let response = try await session.respond(to: prompt)
            messages.append(Message(role: .assistant, text: response.content))
        } catch {
            messages.append(Message(role: .assistant, text: "Error: \(error.localizedDescription)"))
        }
        #else
        messages.append(Message(role: .assistant, text: "FoundationModels not available."))
        #endif

        if case .thinking = state {
            if let bridge {
                let count = bridge.tools.count
                state = .ready(serverName: "Server", toolCount: count)
            } else {
                state = .idle
            }
        }
    }
}

// MARK: - Message

struct Message: Identifiable {
    enum Role { case user, assistant }
    let id = UUID()
    let role: Role
    let text: String
}
