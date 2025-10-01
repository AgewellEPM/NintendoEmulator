import SwiftUI
import CoreInterface
import AppKit
import EmulatorKit

struct ChatSidebarView: View {
    @ObservedObject var chatManager: GameChatManager
    let game: ROMMetadata
    @Binding var isShowing: Bool
    @State private var messageText = ""
    @State private var operatorMode = false
    @State private var isNarrating = false
    @ObservedObject private var theme = UIThemeManager.shared
    @StateObject private var visionService = AIVisionService()
    @StateObject private var streamManager = StreamingManager()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: operatorMode ? "eye.circle.fill" : "message.circle.fill")
                    .font(.title2)
                    .foregroundColor(operatorMode ? .purple : .blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text(operatorMode ? "AI Operator Mode" : "AI Game Assistant")
                        .font(.headline)
                    if operatorMode {
                        Text(isNarrating ? "🔴 Watching & Narrating" : "⏸️ Ready to watch")
                            .font(.caption)
                            .foregroundColor(isNarrating ? .red : .secondary)
                    }
                }

                Spacer()

                // Operator Mode Toggle
                Button(action: {
                    withAnimation {
                        operatorMode.toggle()
                        if !operatorMode {
                            isNarrating = false
                        }
                    }
                }) {
                    Image(systemName: operatorMode ? "eye.slash.fill" : "eye.fill")
                        .font(.title3)
                        .foregroundColor(operatorMode ? .purple : .secondary)
                }
                .buttonStyle(.plain)
                .help(operatorMode ? "Disable Operator Mode" : "Enable Operator Mode")

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

            // Operator Mode Controls
            if operatorMode {
                VStack(spacing: DesignSystem.Spacing.md) {
                    // Start/Stop Narration
                    Button(action: {
                        isNarrating.toggle()
                        if isNarrating {
                            startOperatorMode()
                        } else {
                            stopOperatorMode()
                        }
                    }) {
                        HStack {
                            Image(systemName: isNarrating ? "stop.circle.fill" : "play.circle.fill")
                                .font(.title2)
                            Text(isNarrating ? "Stop Narrating" : "Start AI Narration")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: isNarrating ? [.red, .orange] : [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)

                    // Operator Info
                    VStack(alignment: .leading, spacing: 8) {
                        Label("AI watches your gameplay", systemImage: "eye.fill")
                            .font(.caption)
                        Label("Narrates what you should do", systemImage: "speaker.wave.2.fill")
                            .font(.caption)
                        Label("Uses local AI vision model", systemImage: "cpu")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding()
                .background(.ultraThinMaterial)
            }

            Divider()

            // Input Field (hidden in operator mode)
            if !operatorMode {
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

    private func startOperatorMode() {
        Task {
            // Add system message
            let systemMessage = GameChatMessage(
                content: "🎮 AI Operator Mode activated! I'm now watching your gameplay and will narrate helpful tips...",
                isUser: false,
                timestamp: Date()
            )
            chatManager.messages.append(systemMessage)

            // Start capturing and analyzing frames
            await startFrameCapture()
        }
    }

    private func stopOperatorMode() {
        let systemMessage = GameChatMessage(
            content: "⏸️ AI Operator Mode paused. Click 'Start AI Narration' to resume watching.",
            isUser: false,
            timestamp: Date()
        )
        chatManager.messages.append(systemMessage)
    }

    private func startFrameCapture() async {
        // Start the AI vision service with frame provider
        await visionService.startAnalysis { [weak streamManager] in
            // Capture frame from the streaming manager
            return streamManager?.captureEmulatorFrame()
        }

        // Monitor for new analysis results
        while isNarrating {
            try? await Task.sleep(nanoseconds: 500_000_000) // Check every 0.5s

            if !isNarrating { break }

            // Check if we have a new analysis
            if let analysis = visionService.lastAnalysis,
               let timestamp = visionService.analysisTimestamp {
                // Only show if this is a new analysis (within last 1 second)
                if Date().timeIntervalSince(timestamp) < 1.0 {
                    let aiMessage = GameChatMessage(
                        content: analysis,
                        isUser: false,
                        timestamp: Date()
                    )

                    await MainActor.run {
                        // Check if we already have this message (avoid duplicates)
                        if chatManager.messages.last?.content != analysis {
                            chatManager.messages.append(aiMessage)
                        }
                    }
                }
            }
        }

        // Stop the vision service when narration stops
        visionService.stopAnalysis()
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

