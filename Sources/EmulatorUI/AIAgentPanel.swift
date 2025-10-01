import SwiftUI
import EmulatorKit

/// Control panel for AI Game Agent
public struct AIAgentPanel: View {
    @StateObject private var agent = AIGameAgent()
    @StateObject private var streamManager = StreamingManager()
    @State private var selectedMode: AIGameAgent.AgentMode = .observe

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 36))
                        .foregroundColor(.purple)

                    VStack(alignment: .leading) {
                        Text("AI Game Agent")
                            .font(.title.bold())
                        Text(agent.isPlaying ? "🤖 Playing" : agent.isLearning ? "📚 Learning" : "⏸️ Idle")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding()
            }
            .background(Color(.controlBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Mode Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Agent Mode")
                            .font(.headline)

                        VStack(spacing: 8) {
                            AgentModeButton(
                                mode: .observe,
                                icon: "eye",
                                title: "Observe",
                                description: "AI watches gameplay silently",
                                selected: selectedMode == .observe
                            ) {
                                selectedMode = .observe
                            }

                            AgentModeButton(
                                mode: .learn,
                                icon: "book",
                                title: "Learn from You",
                                description: "AI watches and learns your playstyle",
                                selected: selectedMode == .learn
                            ) {
                                selectedMode = .learn
                            }

                            AgentModeButton(
                                mode: .assist,
                                icon: "lightbulb",
                                title: "Assist",
                                description: "AI suggests moves based on learned behavior",
                                selected: selectedMode == .assist
                            ) {
                                selectedMode = .assist
                            }

                            AgentModeButton(
                                mode: .mimic,
                                icon: "person.2",
                                title: "Mimic Mode",
                                description: "AI copies your style and takes over when you stop",
                                selected: selectedMode == .mimic
                            ) {
                                selectedMode = .mimic
                            }

                            AgentModeButton(
                                mode: .autoplay,
                                icon: "play.circle",
                                title: "Autoplay",
                                description: "AI plays completely autonomously",
                                selected: selectedMode == .autoplay
                            ) {
                                selectedMode = .autoplay
                            }
                        }
                    }

                    Divider()

                    // Agent Status
                    if agent.isPlaying {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Agent Status")
                                .font(.headline)

                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("AI is actively playing")
                                    .font(.callout)
                            }
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)

                            HStack(spacing: 12) {
                                Button("Aggressive Mode") {
                                    // TODO: Connect to SimpleAgent
                                }
                                .buttonStyle(.bordered)

                                Button("Defensive Mode") {
                                    // TODO: Connect to SimpleAgent
                                }
                                .buttonStyle(.bordered)

                                Button("Explorer Mode") {
                                    // TODO: Connect to SimpleAgent
                                }
                                .buttonStyle(.bordered)
                            }
                        }

                        Divider()
                    }

                    // Learning Stats
                    if agent.isLearning || agent.actionsLearned > 0 {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Learning Progress")
                                .font(.headline)

                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Actions Learned")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("\(agent.actionsLearned)")
                                        .font(.title2.bold())
                                }

                                Spacer()

                                VStack(alignment: .leading) {
                                    Text("Confidence")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("\(Int(agent.confidence * 100))%")
                                        .font(.title2.bold())
                                        .foregroundColor(confidenceColor)
                                }
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)

                            ProgressView(value: agent.learningProgress)
                                .progressViewStyle(.linear)
                        }

                        Divider()
                    }

                    // Info about selected mode
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How it Works")
                            .font(.headline)

                        Text(modeDescription)
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Controls
                    VStack(spacing: 12) {
                        if !agent.isLearning && !agent.isPlaying {
                            Button(action: startAgent) {
                                HStack {
                                    Image(systemName: "play.fill")
                                    Text("Start Agent")
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [.purple, .blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button(action: stopAgent) {
                                HStack {
                                    Image(systemName: "stop.fill")
                                    Text("Stop Agent")
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }

                        HStack(spacing: 12) {
                            Button("Export Behaviors") {
                                exportBehaviors()
                            }
                            .buttonStyle(.bordered)
                            .disabled(agent.actionsLearned == 0)

                            Button("Import Behaviors") {
                                importBehaviors()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 500, height: 700)
    }

    private var modeDescription: String {
        switch selectedMode {
        case .observe:
            return "The AI silently watches gameplay to understand the game mechanics. No learning or action is taken."

        case .learn:
            return "The AI observes your gameplay and builds a model of how you play. It records which actions you take in different situations. The more you play, the better it learns your style."

        case .assist:
            return "Based on learned behaviors, the AI suggests moves by analyzing the current game state. You remain in control, but get AI-powered hints."

        case .mimic:
            return "The AI learns your playstyle and seamlessly takes over when you stop providing input. It tries to play exactly like you would. Great for AFK grinding or farming."

        case .autoplay:
            return "The AI plays completely on its own using learned behaviors. Best used after extensive learning. The AI will make decisions based on similar situations it has seen before."
        }
    }

    private var confidenceColor: Color {
        if agent.confidence < 0.3 {
            return .red
        } else if agent.confidence < 0.7 {
            return .orange
        } else {
            return .green
        }
    }

    private func startAgent() {
        Task {
            await agent.startAgent(mode: selectedMode) {
                // Provide frame from stream
                return streamManager.captureEmulatorFrame()
            }
        }
    }

    private func stopAgent() {
        agent.stopAgent()
    }

    private func exportBehaviors() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "ai-behaviors.json"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? agent.exportBehaviors(to: url)
            }
        }
    }

    private func importBehaviors() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false

        panel.begin { response in
            if response == .OK, let url = panel.urls.first {
                try? agent.importBehaviors(from: url)
            }
        }
    }
}

struct AgentModeButton: View {
    let mode: AIGameAgent.AgentMode
    let icon: String
    let title: String
    let description: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(selected ? .white : .blue)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(selected ? .white : .primary)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(selected ? .white.opacity(0.9) : .secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(
                selected ?
                LinearGradient(
                    colors: [.purple, .blue],
                    startPoint: .leading,
                    endPoint: .trailing
                ) :
                LinearGradient(
                    colors: [Color.gray.opacity(0.1), Color.gray.opacity(0.1)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}