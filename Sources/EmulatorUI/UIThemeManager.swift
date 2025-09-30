import SwiftUI

// MARK: - Theme Manager
class UIThemeManager: ObservableObject {
    static let shared = UIThemeManager()

    // Header Settings
    @AppStorage("headerColor") var headerColorHex = "#1a1a1f"
    @AppStorage("headerOpacity") var headerOpacity = 0.95
    @AppStorage("headerTransparency") var headerTransparency = 0.0
    @AppStorage("headerBlur") var headerBlur = true

    // Sidebar Settings
    @AppStorage("sidebarColor") var sidebarColorHex = "#252530"
    @AppStorage("sidebarOpacity") var sidebarOpacity = 0.9
    @AppStorage("sidebarTransparency") var sidebarTransparency = 0.0
    @AppStorage("sidebarWidth") var sidebarWidth = 280.0
    @AppStorage("sidebarBlur") var sidebarBlur = true

    // Chat Settings
    @AppStorage("chatColor") var chatColorHex = "#1e1e25"
    @AppStorage("chatOpacity") var chatOpacity = 0.85
    @AppStorage("chatTransparency") var chatTransparency = 0.0
    @AppStorage("chatMessageBg") var chatMessageBgHex = "#2a2a35"
    @AppStorage("chatBlur") var chatBlur = true

    // Main Window Settings
    @AppStorage("mainWindowColor") var mainWindowColorHex = "#18181b"
    @AppStorage("mainWindowOpacity") var mainWindowOpacity = 1.0
    @AppStorage("mainWindowTransparency") var mainWindowTransparency = 0.0
    @AppStorage("mainContentBlur") var mainContentBlur = false

    // Global Settings
    @AppStorage("accentColor") var accentColorHex = "#007AFF"
    @AppStorage("cornerRadius") var cornerRadius = 12.0
    @AppStorage("animationSpeed") var animationSpeed = 1.0

    // Computed Colors
    var headerColor: Color {
        Color(hex: headerColorHex) ?? .gray
    }

    var sidebarColor: Color {
        Color(hex: sidebarColorHex) ?? .gray
    }

    var chatColor: Color {
        Color(hex: chatColorHex) ?? .gray
    }

    var mainWindowColor: Color {
        Color(hex: mainWindowColorHex) ?? .gray
    }

    var accentColor: Color {
        Color(hex: accentColorHex) ?? .blue
    }

    var chatMessageBg: Color {
        Color(hex: chatMessageBgHex) ?? .gray
    }

    // Reset to defaults
    func resetToDefaults() {
        headerColorHex = "#1a1a1f"
        headerOpacity = 0.95
        headerBlur = true

        sidebarColorHex = "#252530"
        sidebarOpacity = 0.9
        sidebarWidth = 280.0

        chatColorHex = "#1e1e25"
        chatOpacity = 0.85
        chatMessageBgHex = "#2a2a35"

        mainWindowColorHex = "#18181b"
        mainWindowOpacity = 1.0
        mainContentBlur = false

        accentColorHex = "#007AFF"
        cornerRadius = 12.0
        animationSpeed = 1.0
    }
}

// MARK: - Enhanced UI Customization View
struct EnhancedUICustomizationView: View {
    @ObservedObject private var theme = UIThemeManager.shared
    @State private var selectedTab = "header"
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label("UI Theme Settings", systemImage: "paintbrush.fill")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button("Reset All") {
                    theme.resetToDefaults()
                }
                .buttonStyle(.bordered)

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(theme.headerColor.opacity(theme.headerOpacity))

            // Tab Selection
            Picker("", selection: $selectedTab) {
                Text("Header").tag("header")
                Text("Sidebar").tag("sidebar")
                Text("Chat").tag("chat")
                Text("Main").tag("main")
                Text("Global").tag("global")
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()

            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    switch selectedTab {
                    case "header":
                        HeaderSettingsView()
                    case "sidebar":
                        SidebarSettingsView()
                    case "chat":
                        ChatSettingsView()
                    case "main":
                        MainWindowSettingsView()
                    case "global":
                        GlobalSettingsView()
                    default:
                        EmptyView()
                    }
                }
                .padding()
            }

            // Live Preview
            VStack {
                Text("Live Preview")
                    .font(.caption)
                    .foregroundColor(.secondary)

                PreviewMockup(selectedTab: $selectedTab)
                    .frame(height: 150)
                    .padding()
            }
            .background(Color.gray.opacity(0.1))
        }
        .frame(width: 450, height: 600)
    }
}

// MARK: - Header Settings
struct HeaderSettingsView: View {
    @ObservedObject private var theme = UIThemeManager.shared

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            GroupBox(label: Label("Header Appearance", systemImage: "rectangle.topthird.inset.filled")) {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Color Picker
                    HStack {
                        Text("Background Color")
                        Spacer()
                        ColorPicker("", selection: Binding(
                            get: { theme.headerColor },
                            set: { theme.headerColorHex = $0.toHex() ?? "#1a1a1f" }
                        ))
                        .labelsHidden()
                    }

                    // Opacity Slider
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Opacity")
                            Spacer()
                            Text("\(Int(theme.headerOpacity * 100))%")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                        }

                        Slider(value: $theme.headerOpacity, in: 0...1)
                            .accentColor(theme.accentColor)
                    }

                    // Transparency Slider
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Transparency")
                            Spacer()
                            Text("\(Int(theme.headerTransparency * 100))%")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                        }

                        Slider(value: $theme.headerTransparency, in: 0...1)
                            .accentColor(theme.accentColor)
                    }

                    // Blur Toggle
                    Toggle("Enable Background Blur", isOn: $theme.headerBlur)
                }
            }

            // Quick Presets
            GroupBox(label: Label("Quick Presets", systemImage: "sparkles")) {
                HStack(spacing: DesignSystem.Spacing.md) {
                    PresetButton(label: "Dark", color: "#1a1a1f", opacity: 0.95) {
                        theme.headerColorHex = "#1a1a1f"
                        theme.headerOpacity = 0.95
                    }
                    PresetButton(label: "Light", color: "#ffffff", opacity: 0.9) {
                        theme.headerColorHex = "#ffffff"
                        theme.headerOpacity = 0.9
                    }
                    PresetButton(label: "Transparent", color: "#000000", opacity: 0.3) {
                        theme.headerColorHex = "#000000"
                        theme.headerOpacity = 0.3
                    }
                    PresetButton(label: "Accent", color: theme.accentColorHex, opacity: 0.8) {
                        theme.headerColorHex = theme.accentColorHex
                        theme.headerOpacity = 0.8
                    }
                }
            }
        }
    }
}

// MARK: - Sidebar Settings
struct SidebarSettingsView: View {
    @ObservedObject private var theme = UIThemeManager.shared

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            GroupBox(label: Label("Sidebar Appearance", systemImage: "sidebar.left")) {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Color Picker
                    HStack {
                        Text("Background Color")
                        Spacer()
                        ColorPicker("", selection: Binding(
                            get: { theme.sidebarColor },
                            set: { theme.sidebarColorHex = $0.toHex() ?? "#252530" }
                        ))
                        .labelsHidden()
                    }

                    // Opacity Slider
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Opacity")
                            Spacer()
                            Text("\(Int(theme.sidebarOpacity * 100))%")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                        }

                        Slider(value: $theme.sidebarOpacity, in: 0...1)
                            .accentColor(theme.accentColor)
                    }

                    // Transparency Slider
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Transparency")
                            Spacer()
                            Text("\(Int(theme.sidebarTransparency * 100))%")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                        }

                        Slider(value: $theme.sidebarTransparency, in: 0...1)
                            .accentColor(theme.accentColor)
                    }

                    // Width Slider
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Width")
                            Spacer()
                            Text("\(Int(theme.sidebarWidth))px")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                        }

                        Slider(value: $theme.sidebarWidth, in: 200...400, step: 10)
                            .accentColor(theme.accentColor)
                    }

                    // Blur Toggle
                    Toggle("Enable Background Blur", isOn: $theme.sidebarBlur)
                }
            }

            // Quick Presets
            GroupBox(label: Label("Quick Presets", systemImage: "sparkles")) {
                HStack(spacing: DesignSystem.Spacing.md) {
                    PresetButton(label: "Dark", color: "#252530", opacity: 0.9) {
                        theme.sidebarColorHex = "#252530"
                        theme.sidebarOpacity = 0.9
                    }
                    PresetButton(label: "Light", color: "#f5f5f7", opacity: 0.95) {
                        theme.sidebarColorHex = "#f5f5f7"
                        theme.sidebarOpacity = 0.95
                    }
                    PresetButton(label: "Glass", color: "#000000", opacity: 0.2) {
                        theme.sidebarColorHex = "#000000"
                        theme.sidebarOpacity = 0.2
                    }
                    PresetButton(label: "Hidden", color: "#000000", opacity: 0) {
                        theme.sidebarColorHex = "#000000"
                        theme.sidebarOpacity = 0
                    }
                }
            }
        }
    }
}

// MARK: - Chat Settings
struct ChatSettingsView: View {
    @ObservedObject private var theme = UIThemeManager.shared

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            GroupBox(label: Label("Chat Appearance", systemImage: "bubble.left.and.bubble.right")) {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Background Color
                    HStack {
                        Text("Background Color")
                        Spacer()
                        ColorPicker("", selection: Binding(
                            get: { theme.chatColor },
                            set: { theme.chatColorHex = $0.toHex() ?? "#1e1e25" }
                        ))
                        .labelsHidden()
                    }

                    // Message Background Color
                    HStack {
                        Text("Message Background")
                        Spacer()
                        ColorPicker("", selection: Binding(
                            get: { theme.chatMessageBg },
                            set: { theme.chatMessageBgHex = $0.toHex() ?? "#2a2a35" }
                        ))
                        .labelsHidden()
                    }

                    // Opacity Slider
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Opacity")
                            Spacer()
                            Text("\(Int(theme.chatOpacity * 100))%")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                        }

                        Slider(value: $theme.chatOpacity, in: 0...1)
                            .accentColor(theme.accentColor)
                    }

                    // Transparency Slider
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Transparency")
                            Spacer()
                            Text("\(Int(theme.chatTransparency * 100))%")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                        }

                        Slider(value: $theme.chatTransparency, in: 0...1)
                            .accentColor(theme.accentColor)
                    }

                    // Blur Toggle
                    Toggle("Enable Background Blur", isOn: $theme.chatBlur)
                }
            }

            // Quick Presets
            GroupBox(label: Label("Quick Presets", systemImage: "sparkles")) {
                VStack(spacing: DesignSystem.Spacing.md) {
                    HStack(spacing: DesignSystem.Spacing.md) {
                        PresetButton(label: "Dark", color: "#1e1e25", opacity: 0.85) {
                            theme.chatColorHex = "#1e1e25"
                            theme.chatMessageBgHex = "#2a2a35"
                            theme.chatOpacity = 0.85
                        }
                        PresetButton(label: "Light", color: "#ffffff", opacity: 0.95) {
                            theme.chatColorHex = "#ffffff"
                            theme.chatMessageBgHex = "#f0f0f0"
                            theme.chatOpacity = 0.95
                        }
                    }
                    HStack(spacing: DesignSystem.Spacing.md) {
                        PresetButton(label: "Twitch", color: "#9146ff", opacity: 0.1) {
                            theme.chatColorHex = "#9146ff"
                            theme.chatMessageBgHex = "#9146ff"
                            theme.chatOpacity = 0.1
                        }
                        PresetButton(label: "YouTube", color: "#ff0000", opacity: 0.1) {
                            theme.chatColorHex = "#ff0000"
                            theme.chatMessageBgHex = "#ff0000"
                            theme.chatOpacity = 0.1
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Main Window Settings
struct MainWindowSettingsView: View {
    @ObservedObject private var theme = UIThemeManager.shared

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            GroupBox(label: Label("Main Window", systemImage: "macwindow")) {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Color Picker
                    HStack {
                        Text("Background Color")
                        Spacer()
                        ColorPicker("", selection: Binding(
                            get: { theme.mainWindowColor },
                            set: { theme.mainWindowColorHex = $0.toHex() ?? "#18181b" }
                        ))
                        .labelsHidden()
                    }

                    // Opacity Slider
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Opacity")
                            Spacer()
                            Text("\(Int(theme.mainWindowOpacity * 100))%")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                        }

                        Slider(value: $theme.mainWindowOpacity, in: 0...1)
                            .accentColor(theme.accentColor)
                    }

                    // Transparency Slider
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Transparency")
                            Spacer()
                            Text("\(Int(theme.mainWindowTransparency * 100))%")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                        }

                        Slider(value: $theme.mainWindowTransparency, in: 0...1)
                            .accentColor(theme.accentColor)
                    }

                    // Blur Toggle
                    Toggle("Enable Content Blur", isOn: $theme.mainContentBlur)
                }
            }

            // Quick Presets
            GroupBox(label: Label("Quick Presets", systemImage: "sparkles")) {
                HStack(spacing: DesignSystem.Spacing.md) {
                    PresetButton(label: "Dark", color: "#18181b", opacity: 1.0) {
                        theme.mainWindowColorHex = "#18181b"
                        theme.mainWindowOpacity = 1.0
                    }
                    PresetButton(label: "Light", color: "#ffffff", opacity: 1.0) {
                        theme.mainWindowColorHex = "#ffffff"
                        theme.mainWindowOpacity = 1.0
                    }
                    PresetButton(label: "Transparent", color: "#000000", opacity: 0.5) {
                        theme.mainWindowColorHex = "#000000"
                        theme.mainWindowOpacity = 0.5
                    }
                    PresetButton(label: "Gaming", color: "#0a0e27", opacity: 0.95) {
                        theme.mainWindowColorHex = "#0a0e27"
                        theme.mainWindowOpacity = 0.95
                    }
                }
            }
        }
    }
}

// MARK: - Global Settings
struct GlobalSettingsView: View {
    @ObservedObject private var theme = UIThemeManager.shared

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            GroupBox(label: Label("Global Settings", systemImage: "globe")) {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Accent Color
                    HStack {
                        Text("Accent Color")
                        Spacer()
                        ColorPicker("", selection: Binding(
                            get: { theme.accentColor },
                            set: { theme.accentColorHex = $0.toHex() ?? "#007AFF" }
                        ))
                        .labelsHidden()
                    }

                    // Corner Radius
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Corner Radius")
                            Spacer()
                            Text("\(Int(theme.cornerRadius))px")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                        }

                        Slider(value: $theme.cornerRadius, in: 0...24, step: 2)
                            .accentColor(theme.accentColor)
                    }

                    // Animation Speed
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Animation Speed")
                            Spacer()
                            Text("\(String(format: "%.1fx", theme.animationSpeed))")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                        }

                        Slider(value: $theme.animationSpeed, in: 0.5...2.0, step: 0.1)
                            .accentColor(theme.accentColor)
                    }
                }
            }

            // Accent Color Presets
            GroupBox(label: Label("Accent Colors", systemImage: "paintpalette")) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: DesignSystem.Spacing.sm) {
                    ForEach(accentColors, id: \.self) { colorHex in
                        Button(action: { theme.accentColorHex = colorHex }) {
                            Circle()
                                .fill(Color(hex: colorHex) ?? .gray)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: theme.accentColorHex == colorHex ? 2 : 0)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    let accentColors = [
        "#007AFF", "#AF52DE", "#FF2D55", "#FF3B30",
        "#FF9500", "#FFCC00", "#34C759", "#00C7BE",
        "#32ADE6", "#5856D6", "#FF6482", "#A2845E"
    ]
}

// MARK: - Preview Mockup
struct PreviewMockup: View {
    @ObservedObject private var theme = UIThemeManager.shared
    @Binding var selectedTab: String

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar - Clickable
            Button(action: { selectedTab = "sidebar" }) {
                VStack {
                    Text("Sidebar")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(width: 60)
                .frame(maxHeight: .infinity)
                .background(theme.sidebarColor.opacity(theme.sidebarOpacity * (1.0 - theme.sidebarTransparency)))
                .overlay(
                    selectedTab == "sidebar" ?
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(theme.accentColor, lineWidth: 2)
                    : nil
                )
            }
            .buttonStyle(.plain)

            // Main Content
            VStack(spacing: 0) {
                // Header - Clickable
                Button(action: { selectedTab = "header" }) {
                    HStack {
                        Text("Header")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .frame(height: 30)
                    .frame(maxWidth: .infinity)
                    .background(theme.headerColor.opacity(theme.headerOpacity * (1.0 - theme.headerTransparency)))
                    .overlay(
                        selectedTab == "header" ?
                        Rectangle()
                            .stroke(theme.accentColor, lineWidth: 2)
                        : nil
                    )
                }
                .buttonStyle(.plain)

                // Main Window - Clickable
                Button(action: { selectedTab = "main" }) {
                    VStack {
                        Text("Main Window")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(theme.mainWindowColor.opacity(theme.mainWindowOpacity * (1.0 - theme.mainWindowTransparency)))
                    .overlay(
                        selectedTab == "main" ?
                        Rectangle()
                            .stroke(theme.accentColor, lineWidth: 2)
                        : nil
                    )
                }
                .buttonStyle(.plain)
            }

            // Chat - Clickable
            Button(action: { selectedTab = "chat" }) {
                VStack {
                    Text("Chat")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(theme.chatMessageBg.opacity(0.5))
                        .frame(width: 50, height: 10)
                }
                .frame(width: 60)
                .frame(maxHeight: .infinity)
                .background(theme.chatColor.opacity(theme.chatOpacity * (1.0 - theme.chatTransparency)))
                .overlay(
                    selectedTab == "chat" ?
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(theme.accentColor, lineWidth: 2)
                    : nil
                )
            }
            .buttonStyle(.plain)
        }
        .cornerRadius(theme.cornerRadius / 2)
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadius / 2)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Helper Views
struct PresetButton: View {
    let label: String
    let color: String
    let opacity: Double
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignSystem.Spacing.xs) {
                RoundedRectangle(cornerRadius: 4)
                    .fill((Color(hex: color) ?? .gray).opacity(opacity))
                    .frame(height: 20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )

                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

