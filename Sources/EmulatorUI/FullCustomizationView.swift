import SwiftUI
import AppKit

// MARK: - Full Customization View
public struct FullCustomizationView: View {
    @ObservedObject private var baseTheme = UIThemeManager.shared
    @ObservedObject private var theme = ExtendedThemeManager.shared
    @State private var selectedCategory = "cards"
    @Environment(\.dismiss) var dismiss

    public var body: some View {
        VStack(spacing: 0) {
            // NN/g Header: Clear hierarchy with proper spacing
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                HStack {
                    Image(systemName: "desktopcomputer")
                        .font(.title2)
                        .foregroundColor(.accentColor)

                    Text("Complete UI Customization")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Spacer()

                    HStack(spacing: DesignSystem.Spacing.md) {
                        Button(action: exportTheme) {
                            Label("Export Theme", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.bordered)
                        .help("Save your current theme settings")

                        Button(action: importTheme) {
                            Label("Import Theme", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(.bordered)
                        .help("Load a previously saved theme")

                        Button("Done") {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.escape)
                    }
                }

                // NN/g: Descriptive subtitle for context
                Text("Customize the appearance of your content creator toolkit")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            // Category Selection
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.md) {
                    CategoryButton(title: "Cards", icon: "square.stack.3d.up.fill", tag: "cards", selected: $selectedCategory)
                    CategoryButton(title: "Buttons", icon: "button.programmable", tag: "buttons", selected: $selectedCategory)
                    CategoryButton(title: "Tabs", icon: "squares.below.rectangle", tag: "tabs", selected: $selectedCategory)
                    CategoryButton(title: "Text", icon: "textformat", tag: "text", selected: $selectedCategory)
                    CategoryButton(title: "Accents", icon: "paintpalette.fill", tag: "accents", selected: $selectedCategory)
                    CategoryButton(title: "Glass", icon: "cube.transparent.fill", tag: "glass", selected: $selectedCategory)
                    CategoryButton(title: "Grid", icon: "square.grid.3x3", tag: "grid", selected: $selectedCategory)
                    CategoryButton(title: "Animation", icon: "wand.and.rays", tag: "animation", selected: $selectedCategory)
                    CategoryButton(title: "Background", icon: "photo.fill", tag: "background", selected: $selectedCategory)
                    CategoryButton(title: "Desktop", icon: "desktopcomputer", tag: "desktop", selected: $selectedCategory)
                    CategoryButton(title: "Presets", icon: "sparkles", tag: "presets", selected: $selectedCategory)
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.1))

            // Content
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    switch selectedCategory {
                    case "cards":
                        CardCustomizationView()
                    case "buttons":
                        ButtonCustomizationView()
                    case "tabs":
                        TabBarCustomizationView()
                    case "text":
                        TextCustomizationView()
                    case "accents":
                        AccentColorsView()
                    case "glass":
                        GlassEffectView()
                    case "grid":
                        GridCustomizationView()
                    case "animation":
                        AnimationSettingsView()
                    case "background":
                        BackgroundCustomizationView()
                    case "desktop":
                        DesktopCustomizationView()
                    case "presets":
                        ThemePresetsView()
                    default:
                        EmptyView()
                    }
                }
                .padding()
            }
        }
        .frame(width: 600, height: 700)
    }

    private func exportTheme() {
        let panel = NSSavePanel()
        panel.title = "Export Theme"
        panel.message = "Save your custom theme"
        panel.nameFieldStringValue = "CustomTheme.json"
        panel.allowedContentTypes = [.json]

        if panel.runModal() == .OK, let url = panel.url {
            var themeData: [String: Any] = [:]

            // Collect all theme settings
            let defaults = UserDefaults.standard
            let keys = defaults.dictionaryRepresentation().keys

            for key in keys {
                if key.contains("Color") || key.contains("Opacity") || key.contains("Transparency") ||
                   key.contains("Blur") || key.contains("Radius") || key.contains("Width") {
                    themeData[key] = defaults.object(forKey: key)
                }
            }

            do {
                let data = try JSONSerialization.data(withJSONObject: themeData, options: .prettyPrinted)
                try data.write(to: url)
            } catch {
                print("Failed to export theme: \(error)")
            }
        }
    }

    private func importTheme() {
        let panel = NSOpenPanel()
        panel.title = "Import Theme"
        panel.message = "Select a theme file"
        panel.allowedContentTypes = [.json]

        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try Data(contentsOf: url)
                if let themeData = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    for (key, value) in themeData {
                        UserDefaults.standard.set(value, forKey: key)
                    }
                }
            } catch {
                print("Failed to import theme: \(error)")
            }
        }
    }
}

// MARK: - Card Customization
struct CardCustomizationView: View {
    @ObservedObject private var theme = ExtendedThemeManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // NN/g: Primary section with clear visual hierarchy
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                    // Section header with better visual weight
                    HStack(spacing: DesignSystem.Spacing.md) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.accentColor.opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: "square.stack.3d.up.fill")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.accentColor)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Card Appearance")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Customize how cards look throughout the app")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }

                    // NN/g: Background controls in a visual group
                    GroupBox {
                        VStack(spacing: DesignSystem.Spacing.lg) {
                            ColorPickerRow(label: "Background Color", color: Binding(
                                get: { theme.cardBackgroundColor },
                                set: { theme.cardBackgroundColorHex = $0.toHex() ?? "#1C1C1E" }
                            ))

                            // NN/g: Related opacity controls grouped together
                            VStack(spacing: DesignSystem.Spacing.md) {
                                SliderRow(
                                    label: "Opacity",
                                    value: $theme.cardOpacity,
                                    range: 0...1,
                                    showPercentage: true,
                                    description: "Controls the solidity of the background color"
                                )

                                SliderRow(
                                    label: "Transparency",
                                    value: $theme.cardTransparency,
                                    range: 0...1,
                                    showPercentage: true,
                                    description: "Adjusts the see-through glass effect"
                                )

                            }
                        }
                    }

                    // NN/g: Border and Shape controls
                    GroupBox {
                        VStack(spacing: DesignSystem.Spacing.lg) {
                            ColorPickerRow(label: "Border Color", color: Binding(
                                get: { theme.cardBorderColor },
                                set: { theme.cardBorderColorHex = $0.toHex() ?? "#3A3A3C" }
                            ))

                            SliderRow(
                                label: "Border Width",
                                value: $theme.cardBorderWidth,
                                range: 0...5,
                                step: 0.5,
                                unit: "px",
                                description: "Thickness of the card border"
                            )

                            SliderRow(
                                label: "Corner Radius",
                                value: $theme.cardCornerRadius,
                                range: 0...30,
                                unit: "px",
                                description: "Roundness of card corners"
                            )

                            // NN/g: Toggle with icon and description
                            HStack {
                                Toggle(isOn: $theme.cardBlur) {
                                    HStack(spacing: DesignSystem.Spacing.sm) {
                                        Image(systemName: "drop.degreesign")
                                            .foregroundColor(.accentColor)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Enable Blur Effect")
                                                .font(.system(size: 14, weight: .medium))
                                            Text("Adds frosted glass appearance")
                                                .font(.system(size: 11))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .toggleStyle(.switch)
                            }
                        }
                    }
                }

                // NN/g: Shadow Settings as secondary section
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                    HStack(spacing: DesignSystem.Spacing.md) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: "shadow")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Shadow Settings")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Add depth with drop shadows")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }

                    GroupBox {
                        VStack(spacing: DesignSystem.Spacing.lg) {
                            ColorPickerRow(label: "Shadow Color", color: Binding(
                                get: { theme.cardShadowColor },
                                set: { theme.cardShadowColorHex = $0.toHex() ?? "#000000" }
                            ))

                            SliderRow(
                                label: "Shadow Blur",
                                value: $theme.cardShadowRadius,
                                range: 0...20,
                                unit: "px",
                                description: "How soft the shadow appears"
                            )

                            SliderRow(
                                label: "Shadow Opacity",
                                value: $theme.cardShadowOpacity,
                                range: 0...1,
                                showPercentage: true,
                                description: "Shadow darkness level"
                            )
                        }
                    }
                }

                // NN/g: Preview section with proper spacing
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    HStack {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        Text("Live Preview")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Updates in real-time")
                            .font(.system(size: 11))
                            .foregroundColor(Color.secondary.opacity(0.6))
                    }

                    CardPreview()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(DesignSystem.Radius.xxl)
                }
            }
            .padding()
        }
    }
}

// MARK: - Button Customization
struct ButtonCustomizationView: View {
    @ObservedObject private var theme = ExtendedThemeManager.shared

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            GroupBox(label: Label("Button Colors", systemImage: "button.programmable")) {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    ColorPickerRow(label: "Primary", color: Binding(
                        get: { theme.buttonPrimaryColor },
                        set: { theme.buttonPrimaryColorHex = $0.toHex() ?? "#007AFF" }
                    ))

                    ColorPickerRow(label: "Secondary", color: Binding(
                        get: { theme.buttonSecondaryColor },
                        set: { theme.buttonSecondaryColorHex = $0.toHex() ?? "#5AC8FA" }
                    ))

                    ColorPickerRow(label: "Text", color: Binding(
                        get: { theme.buttonTextColor },
                        set: { theme.buttonTextColorHex = $0.toHex() ?? "#FFFFFF" }
                    ))

                    ColorPickerRow(label: "Hover", color: Binding(
                        get: { theme.buttonHoverColor },
                        set: { theme.buttonHoverColorHex = $0.toHex() ?? "#0051D5" }
                    ))

                    SliderRow(label: "Opacity", value: $theme.buttonOpacity, range: 0...1)
                    SliderRow(label: "Corner Radius", value: $theme.buttonCornerRadius, range: 0...20)
                }
            }

            // Button Preview
            ButtonPreview()
        }
    }
}

// MARK: - Tab Bar Customization
struct TabBarCustomizationView: View {
    @ObservedObject private var theme = ExtendedThemeManager.shared

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            GroupBox(label: Label("Tab Bar", systemImage: "squares.below.rectangle")) {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    ColorPickerRow(label: "Background", color: Binding(
                        get: { theme.tabBarColor },
                        set: { theme.tabBarColorHex = $0.toHex() ?? "#2C2C2E" }
                    ))

                    SliderRow(label: "Opacity", value: $theme.tabBarOpacity, range: 0...1)
                    SliderRow(label: "Transparency", value: $theme.tabBarTransparency, range: 0...1)

                    ColorPickerRow(label: "Active Tab", color: Binding(
                        get: { theme.tabBarActiveColor },
                        set: { theme.tabBarActiveColorHex = $0.toHex() ?? "#007AFF" }
                    ))

                    ColorPickerRow(label: "Inactive Tab", color: Binding(
                        get: { theme.tabBarInactiveColor },
                        set: { theme.tabBarInactiveColorHex = $0.toHex() ?? "#8E8E93" }
                    ))
                }
            }

            // Tab Bar Preview
            TabBarPreview()
        }
    }
}

// MARK: - Text Customization
struct TextCustomizationView: View {
    @ObservedObject private var theme = ExtendedThemeManager.shared

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            GroupBox(label: Label("Text Colors", systemImage: "textformat")) {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    ColorPickerRow(label: "Primary", color: Binding(
                        get: { theme.primaryTextColor },
                        set: { theme.primaryTextColorHex = $0.toHex() ?? "#FFFFFF" }
                    ))

                    ColorPickerRow(label: "Secondary", color: Binding(
                        get: { theme.secondaryTextColor },
                        set: { theme.secondaryTextColorHex = $0.toHex() ?? "#8E8E93" }
                    ))

                    ColorPickerRow(label: "Tertiary", color: Binding(
                        get: { theme.tertiaryTextColor },
                        set: { theme.tertiaryTextColorHex = $0.toHex() ?? "#636366" }
                    ))
                }
            }

            // Text Preview
            TextPreview()
        }
    }
}

// MARK: - Accent Colors
struct AccentColorsView: View {
    @ObservedObject private var theme = ExtendedThemeManager.shared

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            GroupBox(label: Label("Section Accents", systemImage: "paintpalette.fill")) {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    ColorPickerRow(label: "Gaming", color: Binding(
                        get: { theme.gamingAccentColor },
                        set: { theme.gamingAccentColorHex = $0.toHex() ?? "#FF2D55" }
                    ))

                    ColorPickerRow(label: "Chat", color: Binding(
                        get: { theme.chatAccentColor },
                        set: { theme.chatAccentColorHex = $0.toHex() ?? "#5856D6" }
                    ))

                    ColorPickerRow(label: "Analytics", color: Binding(
                        get: { theme.analyticsAccentColor },
                        set: { theme.analyticsAccentColorHex = $0.toHex() ?? "#34C759" }
                    ))

                    ColorPickerRow(label: "Income", color: Binding(
                        get: { theme.incomeAccentColor },
                        set: { theme.incomeAccentColorHex = $0.toHex() ?? "#FFD60A" }
                    ))

                    ColorPickerRow(label: "Calendar", color: Binding(
                        get: { theme.calendarAccentColor },
                        set: { theme.calendarAccentColorHex = $0.toHex() ?? "#FF9500" }
                    ))

                    ColorPickerRow(label: "Settings", color: Binding(
                        get: { theme.settingsAccentColor },
                        set: { theme.settingsAccentColorHex = $0.toHex() ?? "#5AC8FA" }
                    ))
                }
            }
        }
    }
}

// MARK: - Glass Effect Settings
struct GlassEffectView: View {
    @ObservedObject private var theme = ExtendedThemeManager.shared

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            GroupBox(label: Label("Glass Effects", systemImage: "cube.transparent.fill")) {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    SliderRow(label: "Intensity", value: $theme.glassIntensity, range: 0...1)
                    SliderRow(label: "Blur Radius", value: $theme.glassBlurRadius, range: 0...50)
                    SliderRow(label: "Saturation", value: $theme.glassSaturation, range: 0...3)

                    ColorPickerRow(label: "Tint Color", color: Binding(
                        get: { theme.glassTintColor },
                        set: { theme.glassTintColorHex = $0.toHex() ?? "#FFFFFF" }
                    ))

                    SliderRow(label: "Tint Opacity", value: $theme.glassTintOpacity, range: 0...0.5)
                }
            }

            // Glass Preview
            GlassPreview()
        }
    }
}

// MARK: - Grid Customization
struct GridCustomizationView: View {
    @ObservedObject private var theme = ExtendedThemeManager.shared

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            GroupBox(label: Label("Grid Layout", systemImage: "square.grid.3x3")) {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    ColorPickerRow(label: "Background", color: Binding(
                        get: { theme.gridBackgroundColor },
                        set: { theme.gridBackgroundColorHex = $0.toHex() ?? "#000000" }
                    ))

                    ColorPickerRow(label: "Grid Lines", color: Binding(
                        get: { theme.gridLineColor },
                        set: { theme.gridLineColorHex = $0.toHex() ?? "#3A3A3C" }
                    ))

                    SliderRow(label: "Line Opacity", value: $theme.gridLineOpacity, range: 0...1)
                    SliderRow(label: "Grid Spacing", value: $theme.gridSpacing, range: 8...32, step: 4)
                }
            }
        }
    }
}

// MARK: - Animation Settings
struct AnimationSettingsView: View {
    @ObservedObject private var baseTheme = UIThemeManager.shared
    @ObservedObject private var theme = ExtendedThemeManager.shared

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            GroupBox(label: Label("Animations", systemImage: "wand.and.rays")) {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    Toggle("Enable Animations", isOn: $theme.animationsEnabled)

                    SliderRow(label: "Animation Speed", value: $baseTheme.animationSpeed, range: 0.5...2, step: 0.1)
                    SliderRow(label: "Transition Duration", value: $theme.transitionDuration, range: 0.1...1, step: 0.1)
                }
            }
        }
    }
}

// MARK: - Helper Views
struct CategoryButton: View {
    let title: String
    let icon: String
    let tag: String
    @Binding var selected: String

    var body: some View {
        Button(action: { selected = tag }) {
            VStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .foregroundColor(selected == tag ? .white : .secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                selected == tag ?
                UIThemeManager.shared.accentColor :
                    Color.clear
            )
            .cornerRadius(DesignSystem.Radius.lg)
        }
        .buttonStyle(.plain)
    }
}

struct ColorPickerRow: View {
    let label: String
    @Binding var color: Color
    var description: String? = nil

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)

                if let description = description {
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // NN/g: Color picker with preview swatch
            HStack(spacing: DesignSystem.Spacing.sm) {
                // Color value preview
                RoundedRectangle(cornerRadius: 6)
                    .fill(color)
                    .frame(width: 32, height: 32)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )

                ColorPicker("", selection: $color)
                    .labelsHidden()
                    .frame(width: 40)
            }
        }
    }
}

struct SliderRow: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1.0
    var showPercentage: Bool = false
    var unit: String? = nil
    var description: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // NN/g: Label with value display
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)

                    if let description = description {
                        Text(description)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // NN/g: Clear value display with proper formatting
                HStack(spacing: 2) {
                    if showPercentage && range.upperBound == 1.0 {
                        Text("\(Int(value * 100))")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                        Text("%")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    } else if let unit = unit {
                        Text(String(format: "%.1f", value))
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                        Text(unit)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    } else {
                        Text(String(format: "%.1f", value))
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(DesignSystem.Radius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
            }

            // NN/g: Slider with tick marks for better reference
            Slider(value: $value, in: range, step: step)
                .accentColor(UIThemeManager.shared.accentColor)
        }
    }
}

// MARK: - Preview Components
struct CardPreview: View {
    @ObservedObject private var theme = ExtendedThemeManager.shared

    var body: some View {
        VStack {
            Text("Card Preview")
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("Sample Card")
                    .font(.headline)
                    .foregroundColor(theme.primaryTextColor)

                Text("This is how your cards will look")
                    .font(.caption)
                    .foregroundColor(theme.secondaryTextColor)
            }
            .padding()
            .background(
                theme.cardBackgroundColor
                    .opacity(theme.cardOpacity * (1.0 - theme.cardTransparency))
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.cardCornerRadius)
                    .stroke(theme.cardBorderColor, lineWidth: theme.cardBorderWidth)
            )
            .cornerRadius(theme.cardCornerRadius)
            .shadow(
                color: theme.cardShadowColor.opacity(theme.cardShadowOpacity),
                radius: theme.cardShadowRadius
            )
        }
        .padding()
    }
}

struct ButtonPreview: View {
    @ObservedObject private var theme = ExtendedThemeManager.shared

    var body: some View {
        VStack {
            Text("Button Preview")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: DesignSystem.Spacing.lg) {
                Button("Primary") {}
                    .buttonStyle(CustomButtonStyle(isPrimary: true))

                Button("Secondary") {}
                    .buttonStyle(CustomButtonStyle(isPrimary: false))
            }
        }
        .padding()
    }
}

struct TabBarPreview: View {
    @ObservedObject private var theme = ExtendedThemeManager.shared
    @State private var selectedTab = 0

    var body: some View {
        VStack {
            Text("Tab Bar Preview")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: DesignSystem.Spacing.xl) {
                ForEach(0..<4) { index in
                    VStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: ["house", "gamecontroller", "bubble.left", "gear"][index])
                            .font(.title3)
                        Text(["Home", "Games", "Chat", "Settings"][index])
                            .font(.caption2)
                    }
                    .foregroundColor(selectedTab == index ? theme.tabBarActiveColor : theme.tabBarInactiveColor)
                    .onTapGesture { selectedTab = index }
                }
            }
            .padding()
            .background(
                theme.tabBarColor
                    .opacity(theme.tabBarOpacity * (1.0 - theme.tabBarTransparency))
            )
            .cornerRadius(DesignSystem.Radius.xxl)
        }
        .padding()
    }
}

struct TextPreview: View {
    @ObservedObject private var theme = ExtendedThemeManager.shared
    @ObservedObject private var baseTheme = UIThemeManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Primary Text")
                .foregroundColor(theme.primaryTextColor)

            Text("Secondary Text")
                .foregroundColor(theme.secondaryTextColor)

            Text("Tertiary Text")
                .foregroundColor(theme.tertiaryTextColor)
        }
        .padding()
        .background(baseTheme.mainWindowColor.opacity(0.5))
        .cornerRadius(DesignSystem.Radius.lg)
    }
}

struct GlassPreview: View {
    @ObservedObject private var theme = ExtendedThemeManager.shared

    var body: some View {
        VStack {
            Text("Glass Effect Preview")
                .font(.caption)
                .foregroundColor(.secondary)

            ZStack {
                // Background pattern
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 100)

                // Glass overlay
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        theme.glassTintColor.opacity(theme.glassTintOpacity)
                    )
                    .blur(radius: theme.glassBlurRadius * 0.1)
                    .opacity(theme.glassIntensity)
                    .frame(height: 80)
                    .padding()
            }
        }
        .padding()
    }
}

// MARK: - Custom Button Style
struct CustomButtonStyle: ButtonStyle {
    @ObservedObject private var theme = ExtendedThemeManager.shared
    let isPrimary: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                isPrimary ? theme.buttonPrimaryColor : theme.buttonSecondaryColor
            )
            .foregroundColor(theme.buttonTextColor)
            .cornerRadius(theme.buttonCornerRadius)
            .opacity(configuration.isPressed ? 0.8 : theme.buttonOpacity)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

// MARK: - Background Customization
struct BackgroundCustomizationView: View {
    @ObservedObject private var theme = ExtendedThemeManager.shared
    @State private var showingImagePicker = false

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            GroupBox(label: Label("Background Type", systemImage: "photo.fill")) {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    Picker("Type", selection: $theme.backgroundType) {
                        ForEach(BackgroundType.allCases, id: \.self) { type in
                            Text(type.rawValue.capitalized).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch theme.backgroundType {
                    case .solid:
                        ColorPickerRow(label: "Color", color: Binding(
                            get: { theme.backgroundSolidColor },
                            set: { theme.backgroundSolidColorHex = $0.toHex() ?? "#000000" }
                        ))

                    case .gradient:
                        ColorPickerRow(label: "Start Color", color: Binding(
                            get: { theme.backgroundGradientStart },
                            set: { theme.backgroundGradientStartHex = $0.toHex() ?? "#000000" }
                        ))
                        ColorPickerRow(label: "End Color", color: Binding(
                            get: { theme.backgroundGradientEnd },
                            set: { theme.backgroundGradientEndHex = $0.toHex() ?? "#0051D5" }
                        ))

                    case .image:
                        HStack {
                            Text("Image")
                                .font(.callout)
                            Spacer()
                            if let path = theme.backgroundImagePath {
                                Text(URL(fileURLWithPath: path).lastPathComponent)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Button("Choose...") {
                                showingImagePicker = true
                            }
                        }
                    }
                }
            }

            // Background Preview
            BackgroundPreview()
        }
        .fileImporter(
            isPresented: $showingImagePicker,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                theme.backgroundImagePath = url.path
            }
        }
    }
}

// MARK: - Theme Presets
struct ThemePresetsView: View {
    @ObservedObject private var theme = ExtendedThemeManager.shared
    @State private var selectedPreset: ThemePreset?

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            GroupBox(label: Label("Built-in Themes", systemImage: "sparkles")) {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    ForEach(ThemePreset.allCases, id: \.self) { preset in
                        HStack {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                Text(preset.rawValue)
                                    .font(.headline)
                                Text(presetDescription(preset))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button("Apply") {
                                theme.applyPresetTheme(preset)
                                selectedPreset = preset
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                        .background(
                            selectedPreset == preset ?
                                Color.accentColor.opacity(0.1) :
                                Color.gray.opacity(0.05)
                        )
                        .cornerRadius(DesignSystem.Radius.lg)
                    }
                }
            }

            Button("Reset to Defaults") {
                theme.resetToDefaults()
                selectedPreset = nil
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
        }
    }

    func presetDescription(_ preset: ThemePreset) -> String {
        switch preset {
        case .darkPro: return "Professional dark theme with subtle glass effects"
        case .neonGamer: return "Vibrant neon colors perfect for gaming streams"
        case .pastelDream: return "Soft pastel colors with light backgrounds"
        case .cyberpunk: return "Futuristic theme with yellow and pink accents"
        case .minimalist: return "Clean, simple design with minimal effects"
        }
    }
}

// MARK: - Background Preview
struct BackgroundPreview: View {
    @ObservedObject private var theme = ExtendedThemeManager.shared

    var body: some View {
        VStack {
            Text("Background Preview")
                .font(.caption)
                .foregroundColor(.secondary)

            ZStack {
                // Background
                Group {
                    switch theme.backgroundType {
                    case .solid:
                        theme.backgroundSolidColor

                    case .gradient:
                        LinearGradient(
                            colors: [theme.backgroundGradientStart, theme.backgroundGradientEnd],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )

                    case .image:
                        if let path = theme.backgroundImagePath,
                           let nsImage = NSImage(contentsOfFile: path) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            Color.black
                        }
                    }
                }
                .frame(height: 150)
                .cornerRadius(DesignSystem.Radius.lg)

                // Sample content overlay
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Text("Content Preview")
                        .font(.headline)
                        .foregroundColor(theme.primaryTextColor)
                    Text("This is how your background will look")
                        .font(.caption)
                        .foregroundColor(theme.secondaryTextColor)
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(DesignSystem.Radius.lg)
            }
        }
        .padding()
    }
}

// MARK: - Desktop Customization
struct DesktopCustomizationView: View {
    @ObservedObject private var theme = ExtendedThemeManager.shared

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            GroupBox(label: Label("Desktop Display", systemImage: "desktopcomputer")) {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Window appearance controls
                    HStack(spacing: DesignSystem.Spacing.md) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.accentColor.opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: "macwindow")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.accentColor)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Window Settings")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Configure how the app appears on your desktop")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }

                    Toggle("Always On Top", isOn: $theme.windowAlwaysOnTop)
                        .help("Keep the content creator toolkit above other windows")

                    Toggle("Hide Dock Icon", isOn: $theme.hideDockIcon)
                        .help("Hide the app icon from the macOS dock")

                    SliderRow(
                        label: "Window Opacity",
                        value: $theme.windowOpacity,
                        range: 0.3...1.0,
                        showPercentage: true,
                        description: "Overall transparency of the app window"
                    )

                    // Display scaling options
                    Picker("Display Scale", selection: $theme.displayScale) {
                        Text("Small (80%)").tag(0.8)
                        Text("Normal (100%)").tag(1.0)
                        Text("Large (120%)").tag(1.2)
                        Text("Extra Large (150%)").tag(1.5)
                    }
                    .pickerStyle(.menu)

                    // Screen positioning for content creators
                    GroupBox("Stream Position") {
                        VStack(spacing: DesignSystem.Spacing.md) {
                            Text("Position for streaming overlays")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            HStack(spacing: DesignSystem.Spacing.lg) {
                                Button("Top Left") { theme.streamPosition = .topLeft }
                                    .buttonStyle(.bordered)
                                Button("Top Right") { theme.streamPosition = .topRight }
                                    .buttonStyle(.bordered)
                                Button("Bottom Left") { theme.streamPosition = .bottomLeft }
                                    .buttonStyle(.bordered)
                                Button("Bottom Right") { theme.streamPosition = .bottomRight }
                                    .buttonStyle(.bordered)
                            }
                        }
                    }
                }
            }

            // Desktop Preview
            DesktopPreview()
        }
    }
}

// MARK: - Desktop Preview
struct DesktopPreview: View {
    @ObservedObject private var theme = ExtendedThemeManager.shared

    var body: some View {
        VStack {
            Text("Desktop Preview")
                .font(.caption)
                .foregroundColor(.secondary)

            ZStack {
                // Desktop background simulation
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(
                        colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(height: 120)

                // App window preview
                VStack(spacing: DesignSystem.Spacing.xs) {
                    HStack {
                        Circle().fill(.red).frame(width: 8, height: 8)
                        Circle().fill(.yellow).frame(width: 8, height: 8)
                        Circle().fill(.green).frame(width: 8, height: 8)
                        Spacer()
                        Image(systemName: "desktopcomputer")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)

                    Text("Content Creator Toolkit")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(theme.primaryTextColor)

                    Rectangle()
                        .fill(theme.cardBackgroundColor.opacity(0.3))
                        .frame(height: 30)
                }
                .padding(6)
                .background(.ultraThinMaterial)
                .cornerRadius(DesignSystem.Radius.md)
                .opacity(theme.windowOpacity)
                .scaleEffect(theme.displayScale * 0.5)
                .position(
                    x: positionX,
                    y: positionY
                )
            }
        }
        .padding()
    }

    private var positionX: CGFloat {
        switch theme.streamPosition {
        case .topLeft, .bottomLeft: return 60
        case .topRight, .bottomRight: return 180
        }
    }

    private var positionY: CGFloat {
        switch theme.streamPosition {
        case .topLeft, .topRight: return 40
        case .bottomLeft, .bottomRight: return 80
        }
    }
}

// MARK: - Themed Glass Card
public struct ThemedGlassCard<Content: View>: View {
    @ObservedObject private var theme = ExtendedThemeManager.shared

    let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding()
            .background(
                ZStack {
                    if theme.cardBlur {
                        VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                            .opacity(theme.glassIntensity)
                    }

                    theme.cardBackgroundColor
                        .opacity(theme.cardOpacity * (1.0 - theme.cardTransparency))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.cardCornerRadius)
                    .stroke(theme.cardBorderColor, lineWidth: theme.cardBorderWidth)
            )
            .cornerRadius(theme.cardCornerRadius)
            .shadow(
                color: theme.cardShadowColor.opacity(theme.cardShadowOpacity),
                radius: theme.cardShadowRadius
            )
    }
}