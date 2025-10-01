import SwiftUI
import CoreInterface

/// Real AI Agent control panel that actually connects to running emulator
public struct AIAgentControlPanel: View {
    @StateObject private var coordinator = AIAgentCoordinator()
    @State private var isConnected = false
    @State private var emulatorPID: pid_t = 0
    @State private var gameName: String = ""
    @State private var selectedMode: AIAgentCoordinator.AgentMode = .balanced
    @State private var selectedPlayer: Int = 0  // 0=Player 1, 1=Player 2, 2=Player 3, 3=Player 4
    @State private var statusMessage: String = "Not connected"
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    // Stats
    @State private var decisionsMade: Int = 0
    @State private var agentStatus: String = "Idle"
    @State private var updateTimer: Timer?

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Connection Section
                    connectionSection

                    if isConnected {
                        Divider()

                        // Agent Mode Selection
                        modeSelectionSection

                        Divider()

                        // Stats
                        statsSection

                        Divider()

                        // Controls
                        controlsSection
                    }
                }
                .padding()
            }
        }
        .frame(width: 500, height: 700)
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            startUpdateTimer()
        }
        .onDisappear {
            stopUpdateTimer()
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 36))
                .foregroundColor(isConnected ? .green : .gray)

            VStack(alignment: .leading) {
                Text("AI Game Agent")
                    .font(.title.bold())
                Text(statusMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Connection indicator
            Circle()
                .fill(isConnected ? Color.green : Color.red)
                .frame(width: 12, height: 12)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
    }

    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Emulator Connection")
                .font(.headline)

            if !isConnected {
                VStack(spacing: 12) {
                    // Player selection (before connecting)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Play as:")
                            .font(.subheadline.bold())

                        HStack(spacing: 8) {
                            ForEach(0..<4, id: \.self) { playerIndex in
                                playerButton(playerIndex)
                            }
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)

                    // Auto-detect button
                    Button(action: autoDetectEmulator) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            Text("Auto-Detect Emulator")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    // Manual PID entry
                    HStack {
                        TextField("PID", value: $emulatorPID, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)

                        TextField("Game Name", text: $gameName)
                            .textFieldStyle(.roundedBorder)

                        Button("Connect") {
                            connectManually()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)

                Text("💡 Tip: Select player, then start mupen64plus and click Auto-Detect")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Connected to: \(gameName)")
                            .font(.subheadline.bold())
                        HStack(spacing: 8) {
                            Text("PID: \(emulatorPID)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("•")
                                .foregroundColor(.secondary)
                            Text("🎮 Player \(selectedPlayer + 1)")
                                .font(.caption.bold())
                                .foregroundColor(.blue)
                        }
                    }

                    Spacer()

                    Button("Disconnect") {
                        disconnect()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }

    private var modeSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI Mode")
                .font(.headline)

            VStack(spacing: 8) {
                modeButton(.aggressive, "🔥 Aggressive", "Offensive play, attacks frequently")
                modeButton(.defensive, "🛡️ Defensive", "Cautious play, avoids damage")
                modeButton(.balanced, "⚖️ Balanced", "Mix of offense and defense")
                modeButton(.explorer, "🔍 Explorer", "Random exploration, tries new things")
            }
        }
    }

    private func modeButton(_ mode: AIAgentCoordinator.AgentMode, _ title: String, _ description: String) -> some View {
        Button(action: { setMode(mode) }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(selectedMode == mode ? .white : .primary)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(selectedMode == mode ? .white.opacity(0.9) : .secondary)
                }

                Spacer()

                if selectedMode == mode {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(selectedMode == mode ? Color.blue : Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    private func playerButton(_ playerIndex: Int) -> some View {
        Button(action: { selectedPlayer = playerIndex }) {
            VStack(spacing: 4) {
                Text("🎮")
                    .font(.title2)
                Text("P\(playerIndex + 1)")
                    .font(.caption.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(selectedPlayer == playerIndex ? Color.blue : Color.gray.opacity(0.2))
            .foregroundColor(selectedPlayer == playerIndex ? .white : .primary)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Statistics")
                .font(.headline)

            HStack(spacing: 20) {
                StatCard(title: "Decisions", value: "\(decisionsMade)")
                StatCard(title: "Status", value: agentStatus)
            }
        }
    }

    private var controlsSection: some View {
        VStack(spacing: 12) {
            if !coordinator.isActive {
                Button(action: startAgent) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start AI Agent")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [.green, .blue],
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
                        Text("Stop AI Agent")
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
        }
    }

    // MARK: - Actions

    private func autoDetectEmulator() {
        statusMessage = "Scanning for emulator..."

        // Find mupen64plus process
        guard let pid = AIAgentCoordinator.findEmulatorProcess() else {
            showError(message: "No running mupen64plus process found.\n\nPlease start the emulator with a ROM first.")
            statusMessage = "No emulator found"
            return
        }

        emulatorPID = pid

        // Try to detect game name from ROM
        gameName = "Super Mario 64" // Default - TODO: detect from process

        // Set player number before connecting
        coordinator.setPlayerNumber(selectedPlayer)

        // Connect
        if coordinator.connectToEmulator(pid: pid, gameName: gameName) {
            isConnected = true
            statusMessage = "Connected to \(gameName) as Player \(selectedPlayer + 1)"
        } else {
            showError(message: "Failed to connect to emulator.\n\nMake sure you have debugger permissions (see entitlements) or run as root with sudo.")
            statusMessage = "Connection failed"
        }
    }

    private func connectManually() {
        guard emulatorPID > 0 else {
            showError(message: "Please enter a valid PID")
            return
        }

        guard !gameName.isEmpty else {
            showError(message: "Please enter a game name")
            return
        }

        statusMessage = "Connecting to PID \(emulatorPID) as Player \(selectedPlayer + 1)..."

        // Set player number before connecting
        coordinator.setPlayerNumber(selectedPlayer)

        if coordinator.connectToEmulator(pid: emulatorPID, gameName: gameName) {
            isConnected = true
            statusMessage = "Connected to \(gameName) as Player \(selectedPlayer + 1)"
        } else {
            showError(message: "Failed to connect to PID \(emulatorPID).\n\nCheck that:\n1. The PID is correct\n2. You have debugger permissions\n3. The process is running")
            statusMessage = "Connection failed"
        }
    }

    private func disconnect() {
        stopAgent()
        coordinator.disconnect()
        isConnected = false
        statusMessage = "Disconnected"
    }

    private func setMode(_ mode: AIAgentCoordinator.AgentMode) {
        selectedMode = mode
        if coordinator.isActive {
            coordinator.setAgentMode(mode)
        }
    }

    private func startAgent() {
        coordinator.startAgent(mode: selectedMode)
    }

    private func stopAgent() {
        coordinator.stopAgent()
    }

    private func showError(message: String) {
        errorMessage = message
        showError = true
    }

    // MARK: - Updates

    private func startUpdateTimer() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            updateStats()
        }
    }

    private func stopUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    private func updateStats() {
        guard isConnected else { return }

        let stats = coordinator.getStats()
        decisionsMade = stats.decisionsMade
        agentStatus = stats.agentStatus
        statusMessage = coordinator.status
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title2.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Preview

#if DEBUG
struct AIAgentControlPanel_Previews: PreviewProvider {
    static var previews: some View {
        AIAgentControlPanel()
    }
}
#endif