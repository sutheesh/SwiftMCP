import SwiftUI

struct ContentView: View {
    @State private var viewModel = MCPViewModel()
    @State private var serverURL = "https://your-mcp-server.example.com/mcp"

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                statusBanner
                messageList
                inputBar
            }
            .navigationTitle("SwiftMCP Demo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { serverToolbarItem }
        }
    }

    // MARK: - Status Banner

    @ViewBuilder
    private var statusBanner: some View {
        switch viewModel.state {
        case .idle:
            banner("Not connected", color: .secondary, systemImage: "antenna.radiowaves.left.and.right.slash")
        case .connecting:
            banner("Connecting…", color: .orange, systemImage: "arrow.trianglehead.2.clockwise")
        case .ready(let name, let count):
            banner("Connected to \(name) · \(count) tool\(count == 1 ? "" : "s")", color: .green, systemImage: "checkmark.circle.fill")
        case .thinking:
            banner("Thinking…", color: .blue, systemImage: "ellipsis.bubble")
        case .error(let msg):
            banner(msg, color: .red, systemImage: "exclamationmark.triangle.fill")
        }
    }

    private func banner(_ text: String, color: Color, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(text)
                .lineLimit(1)
        }
        .font(.footnote.weight(.medium))
        .foregroundStyle(color)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.08))
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if viewModel.messages.isEmpty {
                        emptyState
                    } else {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                }
                .padding()
            }
            .onChange(of: viewModel.messages.count) {
                if let last = viewModel.messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "server.rack")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Connect to an MCP server\nand start chatting.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Ask anything…", text: $viewModel.inputText, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                .onSubmit { submitIfReady() }

            Button {
                submitIfReady()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(canSend ? .blue : .secondary)
            }
            .disabled(!canSend)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var canSend: Bool {
        guard !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        if case .ready = viewModel.state { return true }
        return false
    }

    private func submitIfReady() {
        guard canSend else { return }
        Task { await viewModel.send() }
    }

    // MARK: - Toolbar

    private var serverToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Section("Server URL") {
                    TextField("https://…", text: $serverURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Button {
                    Task { await viewModel.connect(to: serverURL) }
                } label: {
                    Label("Connect", systemImage: "network")
                }
            } label: {
                Image(systemName: "server.rack")
            }
        }
    }
}

// MARK: - MessageBubble

struct MessageBubble: View {
    let message: Message

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 48) }

            Text(message.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(bubbleColor, in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(message.role == .user ? .white : .primary)

            if message.role == .assistant { Spacer(minLength: 48) }
        }
    }

    private var bubbleColor: Color {
        message.role == .user ? .blue : Color(.secondarySystemBackground)
    }
}

#Preview {
    ContentView()
}
