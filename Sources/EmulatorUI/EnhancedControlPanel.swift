import SwiftUI
import EmulatorKit
import CoreInterface

/// Enhanced Control Panel following NN/g Usability Principles
/// - Visibility of System Status
/// - User Control & Freedom
/// - Consistency & Standards
/// - Error Prevention
/// - Recognition Rather Than Recall
/// - Aesthetic & Minimalist Design
struct EnhancedGameControlPanel: View {
    @ObservedObject var emulatorManager: EmulatorManager
    @ObservedObject var videoRecorder: VideoRecorder

    @Binding var isShowingControls: Bool
    @Binding var showingControlsSettings: Bool
    @Binding var showPerformanceOverlay: Bool
    @Binding var videoScale: CGFloat
    @Binding var isFullscreen: Bool
    @Binding var showingSaveStateManager: Bool

    let onQuickSave: () -> Void
    let onQuickLoad: () -> Void
    let onToggleStream: () -> Void
    let onSyncControllers: () -> Void

    // NN/g: System Status Visibility
    private var isPlaying: Bool { emulatorManager.isRunning && !emulatorManager.isPaused }
    private var canSave: Bool { emulatorManager.currentROM != nil }
    private var hasCore: Bool { emulatorManager.currentCore != nil }

    var body: some View {
        HStack(spacing: 0) {
            // Left: Primary Game Controls
            HStack(spacing: DesignSystem.Spacing.md) {
                // Play/Pause - Most Important Action
                if isPlaying {
                    Button(action: { pauseEmulation() }) {
                        Label("Pause", systemImage: "pause.fill")
                            .frame(minWidth: 100)
                    }
                    .actionButtonStyle()
                    .keyboardShortcut(.space, modifiers: [])
                    .help("Pause game (Space)")
                } else if emulatorManager.isPaused {
                    Button(action: { resumeEmulation() }) {
                        Label("Resume", systemImage: "play.fill")
                            .frame(minWidth: 100)
                    }
                    .actionButtonStyle()
                    .keyboardShortcut(.space, modifiers: [])
                    .help("Resume game (Space)")
                } else {
                    Button(action: { startEmulation() }) {
                        Label("Start", systemImage: "play.fill")
                            .frame(minWidth: 100)
                    }
                    .actionButtonStyle()
                    .disabled(!hasCore)
                    .help(hasCore ? "Start game" : "Load a ROM first")
                }

                Divider()
                    .frame(height: DesignSystem.Size.buttonLarge)

                // Quick Save/Load
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Button(action: onQuickSave) {
                        Image(systemName: "square.and.arrow.down")
                            .frame(width: DesignSystem.Size.buttonMedium)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!canSave)
                    .keyboardShortcut("s", modifiers: [.command])
                    .help(canSave ? "Quick Save (⌘S)" : "Start game to save")

                    Button(action: onQuickLoad) {
                        Image(systemName: "square.and.arrow.up")
                            .frame(width: DesignSystem.Size.buttonMedium)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!canSave)
                    .keyboardShortcut("l", modifiers: [.command])
                    .help(canSave ? "Quick Load (⌘L)" : "No save state available")

                    Button(action: { showingSaveStateManager = true }) {
                        Image(systemName: "folder")
                            .frame(width: DesignSystem.Size.buttonMedium)
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                    .help("Save Manager (⌘⇧S)")
                }
            }
            .padding(.leading, DesignSystem.Spacing.lg)

            Spacer()

            // Center: Status Indicators
            HStack(spacing: DesignSystem.Spacing.lg) {
                // FPS Indicator
                if isPlaying {
                    StatusBadge(
                        text: String(format: "%.0f FPS", emulatorManager.performance.fps),
                        color: fpsColor(emulatorManager.performance.fps),
                        icon: "speedometer"
                    )
                }

                // Recording Indicator
                if videoRecorder.isRecording {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Circle()
                            .fill(DesignSystem.Colors.recording)
                            .frame(width: 8, height: 8)
                            .overlay(
                                Circle()
                                    .fill(DesignSystem.Colors.recording)
                                    .scaleEffect(1.5)
                                    .opacity(0.3)
                                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: videoRecorder.isRecording)
                            )
                        Text("REC \(videoRecorder.recordingTimeFormatted)")
                            .font(DesignSystem.Typography.callout)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(DesignSystem.Colors.recording.opacity(0.15))
                    .foregroundColor(DesignSystem.Colors.recording)
                    .cornerRadius(DesignSystem.Radius.md)
                }

                // Game Title
                if let romTitle = emulatorManager.currentROM?.title {
                    Text(romTitle)
                        .font(DesignSystem.Typography.callout)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineLimit(1)
                        .frame(maxWidth: 200)
                }
            }

            Spacer()

            // Right: Secondary Controls
            HStack(spacing: DesignSystem.Spacing.sm) {
                // Recording Control
                if videoRecorder.isRecording {
                    Button(action: { toggleRecording() }) {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: "stop.fill")
                            Text("Stop")
                        }
                        .frame(minWidth: 80)
                    }
                    .buttonStyle(BorderedButtonStyle())
                    .tint(DesignSystem.Colors.error)
                    .help("Stop Recording")
                } else {
                    Button(action: { toggleRecording() }) {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: "record.circle")
                            Text("Record")
                        }
                        .frame(minWidth: 80)
                    }
                    .buttonStyle(BorderedProminentButtonStyle())
                    .help("Start Recording")
                }

                Divider()
                    .frame(height: DesignSystem.Size.buttonLarge)

                // View Controls
                Menu {
                    Button(action: { videoScale = 0.5 }) {
                        Label("50%", systemImage: videoScale == 0.5 ? "checkmark" : "")
                    }
                    Button(action: { videoScale = 1.0 }) {
                        Label("100%", systemImage: videoScale == 1.0 ? "checkmark" : "")
                    }
                    Button(action: { videoScale = 1.5 }) {
                        Label("150%", systemImage: videoScale == 1.5 ? "checkmark" : "")
                    }
                    Button(action: { videoScale = 2.0 }) {
                        Label("200%", systemImage: videoScale == 2.0 ? "checkmark" : "")
                    }

                    Divider()

                    Button(action: { isFullscreen.toggle() }) {
                        Label(isFullscreen ? "Exit Fullscreen" : "Fullscreen", systemImage: "arrow.up.left.and.arrow.down.right")
                    }
                    .keyboardShortcut("f", modifiers: [.command])
                } label: {
                    Image(systemName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .frame(width: DesignSystem.Size.buttonMedium)
                }
                .buttonStyle(.bordered)
                .help("Display Settings")

                // More Options
                Menu {
                    Button(action: { showPerformanceOverlay.toggle() }) {
                        Label("Performance Stats", systemImage: "speedometer")
                    }

                    Button(action: { showingControlsSettings = true }) {
                        Label("Controller Settings", systemImage: "gamecontroller")
                    }

                    Button(action: onSyncControllers) {
                        Label("Sync Controllers", systemImage: "arrow.triangle.2.circlepath")
                    }

                    Divider()

                    Button(action: onToggleStream) {
                        Label("Stream Chat", systemImage: "message")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .frame(width: DesignSystem.Size.buttonMedium)
                }
                .buttonStyle(.bordered)
                .help("More Options")
            }
            .padding(.trailing, DesignSystem.Spacing.lg)
        }
        .frame(height: DesignSystem.Size.controlPanelHeight)
        .background(DesignSystem.Colors.surface)
        .overlay(
            Rectangle()
                .fill(DesignSystem.Colors.divider)
                .frame(height: 1),
            alignment: .top
        )
    }

    // MARK: - Actions

    private func startEmulation() {
        Task {
            try? await emulatorManager.start()
        }
    }

    private func pauseEmulation() {
        Task {
            await emulatorManager.pause()
        }
    }

    private func resumeEmulation() {
        Task {
            try? await emulatorManager.resume()
        }
    }

    private func toggleRecording() {
        Task {
            do {
                if videoRecorder.isRecording {
                    _ = try await videoRecorder.stopRecording()
                } else {
                    try await videoRecorder.startRecording()
                }
            } catch {
                NSLog("Recording error: \(error)")
            }
        }
    }

    // MARK: - Helper

    private func fpsColor(_ fps: Double) -> Color {
        if fps >= 55 { return DesignSystem.Colors.success }
        if fps >= 45 { return DesignSystem.Colors.warning }
        return DesignSystem.Colors.error
    }
}