import SwiftUI

struct ContentView: View {

    @State private var message = ""
    @State private var response = ""
    @State private var isLoading = false

    private let ollama = OllamaService()

    var body: some View {
        NavigationSplitView {

            // MARK: - Sidebar

            VStack(alignment: .leading, spacing: 16) {

                Text("Local AI")
                    .font(.title2)
                    .fontWeight(.semibold)

                Button {
                    message = ""
                    response = ""
                } label: {
                    Label("New Chat", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)

                Divider()

                Text("Chats")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding()
            .frame(minWidth: 200)

        } detail: {

            // MARK: - Main Chat

            VStack(spacing: 0) {

                // Header

                HStack {

                    VStack(alignment: .leading, spacing: 4) {

                        Text("Qwen3 8B")
                            .font(.headline)

                        Text("Running locally")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Circle()
                        .fill(.green)
                        .frame(width: 9, height: 9)

                    Text("Online")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.bar)

                Divider()

                // Conversation

                ScrollView {

                    VStack(alignment: .leading, spacing: 20) {

                        if !response.isEmpty {

                            VStack(alignment: .leading, spacing: 8) {

                                Text("Qwen3")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Text(response)
                                    .textSelection(.enabled)
                            }
                        } else {

                            VStack(spacing: 15) {

                                Spacer()

                                Image(systemName: "cpu")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.secondary)

                                Text("Local AI")
                                    .font(.largeTitle)
                                    .fontWeight(.semibold)

                                Text("Ask Qwen3 8B anything.")
                                    .foregroundStyle(.secondary)

                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(25)
                }

                Divider()

                // Input

                HStack(alignment: .bottom, spacing: 10) {

                    TextField(
                        "Ask anything...",
                        text: $message,
                        axis: .vertical
                    )
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(.quaternary)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 10)
                    )
                    .onSubmit {
                        Task {
                            await sendMessage()
                        }
                    }

                    Button {

                        Task {
                            await sendMessage()
                        }

                    } label: {

                        if isLoading {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.up")
                                .fontWeight(.semibold)
                        }

                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        message
                            .trimmingCharacters(
                                in: .whitespacesAndNewlines
                            )
                            .isEmpty
                        || isLoading
                    )
                }
                .padding()
            }
        }
        .frame(minWidth: 900, minHeight: 600)
    }

    // MARK: - Send Message

    private func sendMessage() async {

        let text = message.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !text.isEmpty else {
            return
        }

        isLoading = true
        response = ""
        message = ""

        do {

            response = try await ollama.sendMessage(text)

        } catch {

            response = "Error: \(error.localizedDescription)"

        }

        isLoading = false
    }
}

#Preview {
    ContentView()
}
