import SwiftUI
import RenderingEngine
import CoreInterface

public struct AdvancedGraphicsSettingsPanel: View {
    @State private var graphicsSettings = GraphicsSettings()
    @State private var previewEnabled = true
    @State private var selectedSystem: EmulatorSystem = .n64

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Graphics Settings")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Spacer()

                Button("Reset to Defaults") {
                    resetToDefaults()
                }
                .buttonStyle(.bordered)

                Button("Apply Optimal Settings") {
                    applyOptimalSettings()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xxl) {
                    // System Selection
                    systemSelectionSection

                    // Enhancement Settings
                    enhancementSection

                    // Scaling Settings
                    scalingSection

                    // Visual Effects
                    visualEffectsSection

                    // Advanced Settings
                    advancedSection

                    // Preview Section
                    if previewEnabled {
                        previewSection
                    }
                }
                .padding()
            }
        }
        .onAppear {
            loadSettings()
        }
    }

    private var systemSelectionSection: some View {
        GroupBox("Target System") {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("Choose the system to optimize graphics settings for:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Picker("System", selection: $selectedSystem) {
                    ForEach(EmulatorSystem.allCases, id: \.self) { system in
                        HStack {
                            Image(systemName: "gamecontroller")
                            Text(system.displayName)
                        }
                        .tag(system)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedSystem) { _ in
                    applyOptimalSettings()
                }
            }
            .padding()
        }
    }

    private var enhancementSection: some View {
        GroupBox("Enhancement Filters") {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                // Filter Selection
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Enhancement Filter")
                        .font(.headline)

                    Picker("Enhancement", selection: $graphicsSettings.enhancement) {
                        ForEach(GraphicsEnhancer.Enhancement.allCases, id: \.self) { enhancement in
                            Text(enhancement.displayName).tag(enhancement)
                        }
                    }
                    .pickerStyle(.menu)

                    Text("Choose from pixel-perfect scaling algorithms to enhance retro graphics")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()

                // Enhancement-specific settings
                if graphicsSettings.enhancement != .none {
                    enhancementSpecificSettings
                }
            }
            .padding()
        }
    }

    private var enhancementSpecificSettings: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            if [.hq2x, .hq3x, .xbrz2x, .xbrz3x].contains(graphicsSettings.enhancement) {
                Text("Pixel Art Enhancement")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("This filter will scale the image by \(graphicsSettings.enhancement.scaleFactor)x using advanced algorithms designed for pixel art.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if graphicsSettings.enhancement == .crtFilter {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("CRT Settings")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    SliderSetting(
                        title: "Curvature",
                        value: $graphicsSettings.crtIntensity,
                        range: 0...1,
                        description: "Screen curvature intensity"
                    )
                }
            }

            if graphicsSettings.enhancement == .scanlines {
                SliderSetting(
                    title: "Scanline Intensity",
                    value: $graphicsSettings.scanlineIntensity,
                    range: 0...1,
                    description: "Strength of scanline effect"
                )
            }
        }
    }

    private var scalingSection: some View {
        GroupBox("Scaling & Resolution") {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                // Scaling method
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Scaling Method")
                        .font(.headline)

                    Picker("Scaling", selection: $graphicsSettings.scaling) {
                        ForEach(GraphicsEnhancer.ScalingMode.allCases, id: \.self) { scaling in
                            Text(scaling.displayName).tag(scaling)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("How to scale the original resolution to fit your screen")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()

                // Scale factor
                SliderSetting(
                    title: "Scale Factor",
                    value: $graphicsSettings.scaleFactor,
                    range: 1...8,
                    step: 0.5,
                    description: "How much to scale the original resolution"
                )

                // Integer scaling toggle
                Toggle("Integer Scaling", isOn: Binding(
                    get: { graphicsSettings.scaleFactor == floor(graphicsSettings.scaleFactor) },
                    set: { if $0 { graphicsSettings.scaleFactor = round(graphicsSettings.scaleFactor) } }
                ))
                .help("Ensures pixel-perfect scaling without blurring")
            }
            .padding()
        }
    }

    private var visualEffectsSection: some View {
        GroupBox("Visual Effects") {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                // Scanlines
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Toggle("Scanlines", isOn: $graphicsSettings.enableScanlines)
                        .font(.headline)

                    if graphicsSettings.enableScanlines {
                        SliderSetting(
                            title: "Intensity",
                            value: $graphicsSettings.scanlineIntensity,
                            range: 0...1,
                            description: "Scanline visibility"
                        )
                    }
                }

                Divider()

                // Sharpening
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Toggle("Sharpening", isOn: $graphicsSettings.enableSharpening)
                        .font(.headline)

                    if graphicsSettings.enableSharpening {
                        SliderSetting(
                            title: "Intensity",
                            value: $graphicsSettings.sharpeningIntensity,
                            range: 0...2,
                            description: "Image sharpening strength"
                        )
                    }
                }

                Divider()

                // Bloom
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Toggle("Bloom Effect", isOn: $graphicsSettings.enableBloom)
                        .font(.headline)

                    if graphicsSettings.enableBloom {
                        SliderSetting(
                            title: "Intensity",
                            value: $graphicsSettings.bloomIntensity,
                            range: 0...1,
                            description: "Bloom glow strength"
                        )
                    }
                }

                Divider()

                // CRT Effect
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Toggle("CRT Monitor Effect", isOn: $graphicsSettings.enableCRT)
                        .font(.headline)

                    if graphicsSettings.enableCRT {
                        SliderSetting(
                            title: "Intensity",
                            value: $graphicsSettings.crtIntensity,
                            range: 0...1,
                            description: "CRT distortion and glow"
                        )
                    }
                }
            }
            .padding()
        }
    }

    private var advancedSection: some View {
        GroupBox("Advanced Settings") {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                Toggle("Real-time Preview", isOn: $previewEnabled)
                    .font(.headline)

                Text("Performance Impact")
                    .font(.headline)

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    HStack {
                        Text("GPU Usage:")
                        Spacer()
                        Text(estimatedGPUUsage)
                            .foregroundColor(gpuUsageColor)
                            .fontWeight(.medium)
                    }

                    HStack {
                        Text("Memory Usage:")
                        Spacer()
                        Text(estimatedMemoryUsage)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Recommended:")
                        Spacer()
                        Text(performanceRecommendation)
                            .foregroundColor(.secondary)
                    }
                }
                .font(.subheadline)
            }
            .padding()
        }
    }

    private var previewSection: some View {
        GroupBox("Preview") {
            VStack(spacing: DesignSystem.Spacing.md) {
                Text("Graphics Preview")
                    .font(.headline)

                // Mock preview image
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 200)
                    .overlay(
                        VStack {
                            Text("Preview Image")
                                .font(.title)
                                .foregroundColor(.white)

                            Text("Settings: \(graphicsSettings.enhancement.displayName)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))

                            Text("Scale: \(String(format: "%.1fx", graphicsSettings.scaleFactor))")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    )

                Text("This preview will show how your graphics settings affect the final image")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }

    // MARK: - Computed Properties

    private var estimatedGPUUsage: String {
        let baseUsage = 20
        let enhancementCost = graphicsSettings.enhancement.scaleFactor * 15
        let effectsCost = (graphicsSettings.enableScanlines ? 5 : 0) +
                         (graphicsSettings.enableSharpening ? 10 : 0) +
                         (graphicsSettings.enableBloom ? 20 : 0) +
                         (graphicsSettings.enableCRT ? 15 : 0)
        let scalingCost = Int(graphicsSettings.scaleFactor * 10)

        let total = baseUsage + Int(enhancementCost) + effectsCost + scalingCost

        switch total {
        case 0..<40: return "Low"
        case 40..<70: return "Medium"
        case 70..<100: return "High"
        default: return "Very High"
        }
    }

    private var gpuUsageColor: Color {
        switch estimatedGPUUsage {
        case "Low": return .green
        case "Medium": return .orange
        case "High": return .red
        default: return .purple
        }
    }

    private var estimatedMemoryUsage: String {
        let baseMB = 50
        let scalingMB = Int(graphicsSettings.scaleFactor * graphicsSettings.scaleFactor * 4)
        let enhancementMB = graphicsSettings.enhancement.scaleFactor * graphicsSettings.enhancement.scaleFactor * 8

        let total = baseMB + scalingMB + enhancementMB

        return "\(total) MB"
    }

    private var performanceRecommendation: String {
        let usage = estimatedGPUUsage
        switch usage {
        case "Low": return "Excellent performance"
        case "Medium": return "Good performance"
        case "High": return "May impact frame rate"
        default: return "High-end GPU recommended"
        }
    }

    // MARK: - Methods

    private func resetToDefaults() {
        graphicsSettings = GraphicsSettings()
    }

    private func applyOptimalSettings() {
        // This would typically use the GraphicsEnhancer to get optimal settings
        switch selectedSystem {
        case .nes:
            graphicsSettings = GraphicsSettings(
                enhancement: .hq2x,
                scaling: .nearestNeighbor,
                scaleFactor: 4.0
            )
            graphicsSettings.enableScanlines = true
            graphicsSettings.scanlineIntensity = 0.3

        case .snes:
            graphicsSettings = GraphicsSettings(
                enhancement: .xbrz2x,
                scaling: .bilinear,
                scaleFactor: 3.0
            )
            graphicsSettings.enableScanlines = true
            graphicsSettings.scanlineIntensity = 0.2

        case .n64:
            graphicsSettings = GraphicsSettings(
                enhancement: .antiAliasing,
                scaling: .bicubic,
                scaleFactor: 2.0
            )
            graphicsSettings.enableSharpening = true

        case .gamecube, .wii:
            graphicsSettings = GraphicsSettings(
                enhancement: .antiAliasing,
                scaling: .lanczos,
                scaleFactor: 1.5
            )
            graphicsSettings.enableBloom = true

        default:
            graphicsSettings = GraphicsSettings(
                enhancement: .bilinearFilter,
                scaling: .bilinear,
                scaleFactor: 2.0
            )
        }
    }

    private func loadSettings() {
        // Load saved settings from UserDefaults or similar
    }

    private func saveSettings() {
        // Save current settings
    }
}

// MARK: - Supporting Views

struct SliderSetting: View {
    let title: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    var step: Float = 0.1
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack {
                Text(title)
                    .font(.subheadline)
                Spacer()
                Text(String(format: "%.1f", value))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Slider(value: $value, in: range, step: step)

            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
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
}

#if DEBUG
struct AdvancedGraphicsSettingsPanel_Previews: PreviewProvider {
    static var previews: some View {
        AdvancedGraphicsSettingsPanel()
    }
}
#endif
