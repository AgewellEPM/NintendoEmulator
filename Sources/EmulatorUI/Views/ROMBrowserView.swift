import SwiftUI
import Foundation
import UniformTypeIdentifiers
import CoreInterface
import EmulatorKit

public struct ROMBrowserView: View {
    @EnvironmentObject private var romManager: ROMManager
    @EnvironmentObject private var emulatorManager: EmulatorManager
    @State private var showingFilePicker = false
    @State private var selectedROM: ROMMetadata?
    @Binding var selectedGame: ROMMetadata?
    @State private var selectedSystemFilter: EmulatorSystem? = nil
    @State private var showEmulatorDrawer = false

    public init(selectedGame: Binding<ROMMetadata?>) {
        self._selectedGame = selectedGame
    }

    public var body: some View {
        ZStack(alignment: .leading) {
        HStack(spacing: 0) {
            // Left sidebar with ROM library
            VStack {
                // Header
                HStack {
                    Text("ROM Library")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Spacer()

                    // Toggle to slide out emulator list
                    Button(action: { withAnimation(.easeInOut) { showEmulatorDrawer.toggle() } }) {
                        Label("Emulators", systemImage: "sidebar.left")
                    }
                    .buttonStyle(.bordered)

                    // Optimize button
                    OptimizeLibraryButton()
                        .environmentObject(romManager)

                    Button(action: {
                        showingFilePicker = true
                    }) {
                        Label("Add ROM", systemImage: "plus.circle.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()

                // ROM Grid
                if filteredROMs().isEmpty {
                    EmptyStateView {
                        showingFilePicker = true
                    }
                } else {
                    ROMGridView(roms: filteredROMs()) { rom in
                        selectedROM = rom
                        selectedGame = rom
                    }
                }

                Spacer()
            }
            .frame(width: 350)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Right panel for game details
            VStack(spacing: 0) {
                // Inline emulator preview area
                emulatorPreview
                Divider()
                if let selectedGame = selectedGame {
                    GameDetailsView(game: selectedGame)
                        .environmentObject(romManager)
                } else {
                    // Empty state for details panel
                    VStack(spacing: DesignSystem.Spacing.xl) {
                        Image(systemName: "gamecontroller")
                            .font(.system(size: 80))
                            .foregroundColor(.secondary.opacity(0.5))

                        VStack(spacing: DesignSystem.Spacing.sm) {
                            Text("Select a Game")
                                .font(.title2.bold())
                                .foregroundColor(.secondary)

                            Text("Choose a ROM from your library to view details and play a preview above.")
                                .font(.body)
                                .foregroundColor(.secondary.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .lineSpacing(2)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(40)
                }
            }
        }
        // Slide-out emulator drawer
        if showEmulatorDrawer { emulatorDrawer }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.data],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                Task {
                    await romManager.addROMs(from: urls)
                }
            case .failure(let error):
                NSLog("File picker error: %@", String(describing: error))
            }
        }
        .sheet(item: $selectedROM) { rom in
            ROMDetailsView(rom: rom) { selectedRom in
                selectedGame = selectedRom
                selectedROM = nil
            }
        }
        .task {
            await romManager.loadROMs()
        }
    }

    private func filteredROMs() -> [ROMMetadata] {
        guard let system = selectedSystemFilter else { return romManager.roms }
        return romManager.roms.filter { $0.system == system }
    }

    // Emulator preview embedded in the Games area
    @ViewBuilder
    private var emulatorPreview: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Label("Emulator Preview", systemImage: "display")
                    .font(.headline)
                Spacer()
                // Quick controls
                Button(action: { Task { await stopPreview() } }) {
                    Label("Stop", systemImage: "stop.fill")
                }
                .disabled(!(emulatorManager.isRunning || emulatorManager.currentCore != nil))

                if emulatorManager.isPaused {
                    Button(action: { Task { try? await emulatorManager.resume() } }) {
                        Label("Resume", systemImage: "play.fill")
                    }
                } else {
                    Button(action: { Task { await emulatorManager.pause() } }) {
                        Label("Pause", systemImage: "pause.fill")
                    }
                    .disabled(!emulatorManager.isRunning)
                }

                Button(action: { Task { await loadSelectedIntoPreview() } }) {
                    Label("Play Selected", systemImage: "gamecontroller.fill")
                }
                .disabled(selectedGame == nil)
            }

            ZStack {
                if emulatorManager.currentCore != nil {
                    EmulatorMetalViewRepresentable(emulatorManager: emulatorManager)
                        .frame(height: 260)
                        .background(Color.black)
                        .cornerRadius(DesignSystem.Radius.lg)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black)
                        .frame(height: 200)
                        .overlay(
                            VStack(spacing: DesignSystem.Spacing.sm) {
                                Image(systemName: "gamecontroller")
                                    .foregroundColor(.white.opacity(0.7))
                                    .font(.system(size: 36))
                                Text("Select a game and press ‘Play Selected’")
                                    .foregroundColor(.white.opacity(0.8))
                                    .font(.caption)
                            }
                        )
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func loadSelectedIntoPreview() async {
        guard let rom = selectedGame else { return }
        do {
            try await emulatorManager.openROM(at: rom.path)
            try await emulatorManager.start()
        } catch {
            NSLog("Failed to start preview: %@", String(describing: error))
        }
    }

    private func stopPreview() async {
        await emulatorManager.stop()
    }

    // MARK: - Emulator Drawer
    private var emulatorDrawer: some View {
        ZStack(alignment: .leading) {
            // Dimmed backdrop to close
            Color.black.opacity(0.2)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut) { showEmulatorDrawer = false }
                }

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Label("Emulators", systemImage: "cpu")
                        .font(.headline)
                    Spacer()
                    Button(action: { withAnimation(.easeInOut) { showEmulatorDrawer = false } }) {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding()

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        // All systems
                        Button(action: {
                            selectedSystemFilter = nil
                            withAnimation(.easeInOut) { showEmulatorDrawer = false }
                        }) {
                            HStack {
                                Image(systemName: "rectangle.stack.fill")
                                Text("All Systems")
                                Spacer()
                                Text("\(romManager.roms.count)")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)

                        ForEach(EmulatorSystem.allCases, id: \.self) { system in
                            Button(action: {
                                selectedSystemFilter = system
                                withAnimation(.easeInOut) { showEmulatorDrawer = false }
                            }) {
                                HStack {
                                    Image(systemName: systemIcon(for: system))
                                        .foregroundStyle(systemColor(for: system))
                                    Text(system.displayName)
                                        .lineLimit(1)
                                    Spacer()
                                    Text("\(romManager.roms.filter { $0.system == system }.count)")
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                }
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
            }
            .frame(width: 280)
            .background(Color(NSColor.windowBackgroundColor))
            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 0)
            .transition(.move(edge: .leading).combined(with: .opacity))
        }
    }

    // MARK: - Helpers for system icon/color in this view
    private func systemIcon(for system: EmulatorSystem) -> String {
        switch system {
        case .gb, .gbc, .gba: return "gamecontroller"
        case .nes: return "rectangle.fill"
        case .snes: return "rectangle.portrait.fill"
        case .n64: return "cube.fill"
        case .gamecube: return "cube.transparent.fill"
        case .wii, .wiiu: return "wand.and.rays"
        case .ds: return "laptopcomputer"
        case .threeds: return "laptopcomputer.and.iphone"
        case .switchConsole: return "gamecontroller.fill"
        }
    }

    private func systemColor(for system: EmulatorSystem) -> Color {
        switch system {
        case .gb, .gbc, .gba: return .yellow
        case .nes: return .red
        case .snes: return .purple
        case .n64: return .blue
        case .gamecube: return .indigo
        case .wii, .wiiu: return .cyan
        case .ds: return .green
        case .threeds: return .mint
        case .switchConsole: return .orange
        }
    }
}

struct EmptyStateView: View {
    let onAddROMs: () -> Void

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Image(systemName: "gamecontroller")
                .font(.system(size: 80))
                .foregroundColor(.secondary)

            Text("No ROMs Found")
                .font(.title)
                .fontWeight(.semibold)

            Text("Add some homebrew ROMs to get started!")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Add ROMs") {
                onAddROMs()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(40)
    }
}

struct ROMGridView: View {
    let roms: [ROMMetadata]
    let onROMSelected: (ROMMetadata) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 200, maximum: 250))
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: DesignSystem.Spacing.xl) {
                ForEach(roms, id: \.path) { rom in
                    ROMCardView(rom: rom) {
                        onROMSelected(rom)
                    }
                }
            }
            .padding()
        }
    }
}

struct ROMCardView: View {
    let rom: ROMMetadata
    let onTap: () -> Void
    @StateObject private var fetcher = GameMetadataFetcher()
    @State private var metadata: GameMetadataFetcher.GameMetadata?
    @State private var customThumbnail: NSImage?
    @StateObject private var storageManager = ImageStorageManager.shared

    var body: some View {
        ZStack {
            // Use custom thumbnail or box art for background
            if let thumbnail = customThumbnail ?? metadata?.boxArtImage {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 3)
                    .opacity(0.3)
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                // Display custom thumbnail first, then box art, then fallback
                ZStack {
                    if let thumbnail = customThumbnail ?? metadata?.boxArtImage {
                        Image(nsImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 120)
                            .cornerRadius(DesignSystem.Radius.lg)
                            .shadow(radius: 3)
                    } else {
                        // System Icon fallback
                        HStack {
                            Spacer()
                            Image(systemName: systemIcon(for: rom.system))
                                .font(.system(size: 50))
                                .foregroundColor(systemColor(for: rom.system))
                            Spacer()
                        }
                        .frame(height: 100)
                        .background(
                            LinearGradient(
                                colors: [systemColor(for: rom.system).opacity(0.3), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(DesignSystem.Radius.lg)
                    }

                    // N64 overlay logo
                    if customThumbnail != nil || metadata?.boxArtImage != nil {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Text("N64")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(2)
                                    .background(Color.black.opacity(0.3))
                                    .cornerRadius(3)
                                    .padding(DesignSystem.Spacing.xs)
                            }
                        }
                    }
                }

                // ROM Title
                Text(metadata?.title ?? rom.title)
                    .font(.headline)
                    .lineLimit(1)
                    .multilineTextAlignment(.leading)

                // Game info
                if let metadata = metadata {
                    HStack {
                        if !metadata.genre.isEmpty {
                            Text(metadata.genre)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(DesignSystem.Radius.sm)
                        }

                        if metadata.rating > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                    .foregroundColor(.yellow)
                                Text(String(format: "%.1f", metadata.rating))
                                    .font(.caption2)
                            }
                        }

                        Spacer()
                    }
                } else {
                    // ROM Info fallback
                    HStack {
                        Label(formatFileSize(rom.size), systemImage: "doc")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }

                Spacer()
            }
            .padding()
        }
        .frame(height: 220)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(DesignSystem.Radius.xxl)
        .shadow(radius: 2)
        .onTapGesture {
            onTap()
        }
        .task {
            metadata = fetcher.getCachedMetadata(for: rom.title)
            // Load custom thumbnail if it exists
            customThumbnail = storageManager.loadImage(gameTitle: rom.title, imageType: .libraryThumbnail)
        }
        // hoverEffect is unavailable on macOS; omitted
    }

    private func systemIcon(for system: EmulatorSystem) -> String {
        switch system {
        case .gb, .gbc, .gba: return "gamecontroller"
        case .nes: return "rectangle.fill"
        case .snes: return "rectangle.portrait.fill"
        case .n64: return "cube.fill"
        case .gamecube: return "cube.transparent.fill"
        case .wii, .wiiu: return "wand.and.rays"
        case .ds: return "laptopcomputer"
        case .threeds: return "laptopcomputer.and.iphone"
        case .switchConsole: return "gamecontroller.fill"
        }
    }

    private func systemColor(for system: EmulatorSystem) -> Color {
        switch system {
        case .gb, .gbc, .gba: return .yellow
        case .nes: return .red
        case .snes: return .purple
        case .n64: return .blue
        case .gamecube: return .indigo
        case .wii, .wiiu: return .cyan
        case .ds: return .green
        case .threeds: return .mint
        case .switchConsole: return .orange
        }
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

struct ROMDetailsView: View {
    let rom: ROMMetadata
    let onPlay: (ROMMetadata) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header with game info
            VStack(spacing: DesignSystem.Spacing.lg) {
                HStack {
                    Image(systemName: systemIcon(for: rom.system))
                        .font(.system(size: 40))
                        .foregroundColor(systemColor(for: rom.system))

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text(rom.title)
                            .font(.title2)
                            .fontWeight(.bold)

                        Text(rom.system.displayName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        if let region = rom.region {
                            Text(region)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(systemColor(for: rom.system).opacity(0.2))
                                .cornerRadius(DesignSystem.Radius.sm)
                        }
                    }

                    Spacer()
                }

                // Large Play Button
                Button(action: {
                    onPlay(rom)
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                            .font(.title2)
                        Text("Start Game")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Game Details
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                Text("Game Information")
                    .font(.headline)
                    .padding(.bottom, 4)

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    GameInfoRow(icon: "gamecontroller", label: "System", value: rom.system.displayName)
                    GameInfoRow(icon: "doc", label: "File Size", value: formatFileSize(rom.size))
                    GameInfoRow(icon: "folder", label: "Filename", value: rom.path.lastPathComponent)
                }

                Spacer()

                // Close button
                HStack {
                    Spacer()
                    Button("Close") {
                        dismiss()
                    }
                    .keyboardShortcut(.escape)
                }
            }
            .padding()
        }
        .frame(width: 500, height: 400)
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func systemIcon(for system: EmulatorSystem) -> String {
        switch system {
        case .gb, .gbc, .gba: return "gamecontroller"
        case .nes: return "rectangle.fill"
        case .snes: return "rectangle.portrait.fill"
        case .n64: return "cube.fill"
        case .gamecube: return "cube.transparent.fill"
        case .wii, .wiiu: return "wand.and.rays"
        case .ds: return "laptopcomputer"
        case .threeds: return "laptopcomputer.and.iphone"
        case .switchConsole: return "gamecontroller.fill"
        }
    }

    private func systemColor(for system: EmulatorSystem) -> Color {
        switch system {
        case .gb, .gbc, .gba: return .yellow
        case .nes: return .red
        case .snes: return .purple
        case .n64: return .blue
        case .gamecube: return .indigo
        case .wii, .wiiu: return .cyan
        case .ds: return .green
        case .threeds: return .mint
        case .switchConsole: return .orange
        }
    }
}

struct ROMInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .fontWeight(.medium)
                .frame(width: 80, alignment: .leading)

            Text(value)
                .foregroundColor(.secondary)

            Spacer()
        }
    }
}

struct GameInfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)

            Text(label)
                .fontWeight(.medium)
                .frame(width: 80, alignment: .leading)

            Text(value)
                .foregroundColor(.secondary)

            Spacer()
        }
    }
}

#if DEBUG
struct ROMBrowserView_Previews: PreviewProvider {
    static var previews: some View {
        ROMBrowserView(selectedGame: .constant(nil))
    }
}
#endif
