import SwiftUI
import CoreInterface
import AppKit

struct ChatSidebarView: View {
    @ObservedObject var chatManager: GameChatManager
    let game: ROMMetadata
    @Binding var isShowing: Bool
    @State private var messageText = ""
    @ObservedObject private var theme = UIThemeManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "message.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)

                Text("AI Game Assistant")
                    .font(.headline)

                Spacer()

                Button(action: { isShowing = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(.ultraThinMaterial)

            Divider()

            // Chat Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        ForEach(chatManager.messages) { message in
                            ChatMessageBubble(message: message)
                                .id(message.id)
                        }

                        if chatManager.isLoading {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("AI is thinking...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                        }
                    }
                    .padding()
                }
                .onChange(of: chatManager.messages.count) { _ in
                    if let lastMessage = chatManager.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Input Field
            HStack {
                TextField("Ask about \(game.title)...", text: $messageText)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(DesignSystem.Radius.lg)
                    .onSubmit {
                        sendMessage()
                    }

                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(messageText.isEmpty ? .secondary : .blue)
                }
                .disabled(messageText.isEmpty || chatManager.isLoading)
                .buttonStyle(.plain)
            }
            .padding()
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.2), radius: 10, x: -5, y: 0)
    }

    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        Task {
            await chatManager.sendMessage(messageText)
            messageText = ""
        }
    }
}

struct ChatMessageBubble: View {
    let message: GameChatMessage
    @ObservedObject private var theme = UIThemeManager.shared

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            if message.isUser {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: DesignSystem.Spacing.xs) {
                Text(message.content)
                    .font(.body)
                    .foregroundColor(message.isUser ? .white : .primary)
                    .padding(DesignSystem.Spacing.md)
                    .background(
                        message.isUser ?
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [Color.gray.opacity(0.2), Color.gray.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(16)

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if !message.isUser {
                Spacer(minLength: 60)
            }
        }
    }
}

