import SwiftUI
import Foundation

// MARK: - Extended Theme Manager with Full Customization
public class ExtendedThemeManager: ObservableObject {
    public static let shared = ExtendedThemeManager()

    private let defaults = UserDefaults.standard

    // MARK: - Card Customization
    @Published var cardBackgroundColorHex: String {
        didSet { defaults.set(cardBackgroundColorHex, forKey: "cardBackgroundColorHex") }
    }
    @Published var cardOpacity: Double {
        didSet { defaults.set(cardOpacity, forKey: "cardOpacity") }
    }
    @Published var cardTransparency: Double {
        didSet { defaults.set(cardTransparency, forKey: "cardTransparency") }
    }
    @Published var cardBorderColorHex: String {
        didSet { defaults.set(cardBorderColorHex, forKey: "cardBorderColorHex") }
    }
    @Published var cardBorderWidth: Double {
        didSet { defaults.set(cardBorderWidth, forKey: "cardBorderWidth") }
    }
    @Published var cardCornerRadius: Double {
        didSet { defaults.set(cardCornerRadius, forKey: "cardCornerRadius") }
    }
    @Published var cardBlur: Bool {
        didSet { defaults.set(cardBlur, forKey: "cardBlur") }
    }
    @Published var cardShadowColorHex: String {
        didSet { defaults.set(cardShadowColorHex, forKey: "cardShadowColorHex") }
    }
    @Published var cardShadowRadius: Double {
        didSet { defaults.set(cardShadowRadius, forKey: "cardShadowRadius") }
    }
    @Published var cardShadowOpacity: Double {
        didSet { defaults.set(cardShadowOpacity, forKey: "cardShadowOpacity") }
    }

    // MARK: - Button Customization
    @Published var buttonPrimaryColorHex: String {
        didSet { defaults.set(buttonPrimaryColorHex, forKey: "buttonPrimaryColorHex") }
    }
    @Published var buttonSecondaryColorHex: String {
        didSet { defaults.set(buttonSecondaryColorHex, forKey: "buttonSecondaryColorHex") }
    }
    @Published var buttonTextColorHex: String {
        didSet { defaults.set(buttonTextColorHex, forKey: "buttonTextColorHex") }
    }
    @Published var buttonHoverColorHex: String {
        didSet { defaults.set(buttonHoverColorHex, forKey: "buttonHoverColorHex") }
    }
    @Published var buttonOpacity: Double {
        didSet { defaults.set(buttonOpacity, forKey: "buttonOpacity") }
    }
    @Published var buttonCornerRadius: Double {
        didSet { defaults.set(buttonCornerRadius, forKey: "buttonCornerRadius") }
    }

    // MARK: - Tab Bar Customization
    @Published var tabBarColorHex: String {
        didSet { defaults.set(tabBarColorHex, forKey: "tabBarColorHex") }
    }
    @Published var tabBarOpacity: Double {
        didSet { defaults.set(tabBarOpacity, forKey: "tabBarOpacity") }
    }
    @Published var tabBarTransparency: Double {
        didSet { defaults.set(tabBarTransparency, forKey: "tabBarTransparency") }
    }
    @Published var tabBarActiveColorHex: String {
        didSet { defaults.set(tabBarActiveColorHex, forKey: "tabBarActiveColorHex") }
    }
    @Published var tabBarInactiveColorHex: String {
        didSet { defaults.set(tabBarInactiveColorHex, forKey: "tabBarInactiveColorHex") }
    }

    // MARK: - Text Colors
    @Published var primaryTextColorHex: String {
        didSet { defaults.set(primaryTextColorHex, forKey: "primaryTextColorHex") }
    }
    @Published var secondaryTextColorHex: String {
        didSet { defaults.set(secondaryTextColorHex, forKey: "secondaryTextColorHex") }
    }
    @Published var tertiaryTextColorHex: String {
        didSet { defaults.set(tertiaryTextColorHex, forKey: "tertiaryTextColorHex") }
    }

    // MARK: - Accent Colors for Sections
    @Published var gamingAccentColorHex: String {
        didSet { defaults.set(gamingAccentColorHex, forKey: "gamingAccentColorHex") }
    }
    @Published var chatAccentColorHex: String {
        didSet { defaults.set(chatAccentColorHex, forKey: "chatAccentColorHex") }
    }
    @Published var analyticsAccentColorHex: String {
        didSet { defaults.set(analyticsAccentColorHex, forKey: "analyticsAccentColorHex") }
    }
    @Published var incomeAccentColorHex: String {
        didSet { defaults.set(incomeAccentColorHex, forKey: "incomeAccentColorHex") }
    }
    @Published var calendarAccentColorHex: String {
        didSet { defaults.set(calendarAccentColorHex, forKey: "calendarAccentColorHex") }
    }
    @Published var settingsAccentColorHex: String {
        didSet { defaults.set(settingsAccentColorHex, forKey: "settingsAccentColorHex") }
    }

    // MARK: - Glass Effects
    @Published var glassIntensity: Double {
        didSet { defaults.set(glassIntensity, forKey: "glassIntensity") }
    }
    @Published var glassBlurRadius: Double {
        didSet { defaults.set(glassBlurRadius, forKey: "glassBlurRadius") }
    }
    @Published var glassSaturation: Double {
        didSet { defaults.set(glassSaturation, forKey: "glassSaturation") }
    }
    @Published var glassTintColorHex: String {
        didSet { defaults.set(glassTintColorHex, forKey: "glassTintColorHex") }
    }
    @Published var glassTintOpacity: Double {
        didSet { defaults.set(glassTintOpacity, forKey: "glassTintOpacity") }
    }

    // MARK: - Grid Customization
    @Published var gridBackgroundColorHex: String {
        didSet { defaults.set(gridBackgroundColorHex, forKey: "gridBackgroundColorHex") }
    }
    @Published var gridLineColorHex: String {
        didSet { defaults.set(gridLineColorHex, forKey: "gridLineColorHex") }
    }
    @Published var gridLineOpacity: Double {
        didSet { defaults.set(gridLineOpacity, forKey: "gridLineOpacity") }
    }
    @Published var gridSpacing: Double {
        didSet { defaults.set(gridSpacing, forKey: "gridSpacing") }
    }

    // MARK: - Animation Settings
    @Published var animationsEnabled: Bool {
        didSet { defaults.set(animationsEnabled, forKey: "animationsEnabled") }
    }
    @Published var transitionDuration: Double {
        didSet { defaults.set(transitionDuration, forKey: "transitionDuration") }
    }

    // MARK: - Background Settings
    @Published var backgroundType: BackgroundType {
        didSet { defaults.set(backgroundType.rawValue, forKey: "backgroundType") }
    }
    @Published var backgroundImagePath: String? {
        didSet { defaults.set(backgroundImagePath, forKey: "backgroundImagePath") }
    }
    @Published var backgroundGradientStartHex: String {
        didSet { defaults.set(backgroundGradientStartHex, forKey: "backgroundGradientStartHex") }
    }
    @Published var backgroundGradientEndHex: String {
        didSet { defaults.set(backgroundGradientEndHex, forKey: "backgroundGradientEndHex") }
    }
    @Published var backgroundSolidColorHex: String {
        didSet { defaults.set(backgroundSolidColorHex, forKey: "backgroundSolidColorHex") }
    }

    // MARK: - Desktop Settings
    @Published var windowAlwaysOnTop: Bool {
        didSet { defaults.set(windowAlwaysOnTop, forKey: "windowAlwaysOnTop") }
    }
    @Published var hideDockIcon: Bool {
        didSet { defaults.set(hideDockIcon, forKey: "hideDockIcon") }
    }
    @Published var windowOpacity: Double {
        didSet { defaults.set(windowOpacity, forKey: "windowOpacity") }
    }
    @Published var displayScale: Double {
        didSet { defaults.set(displayScale, forKey: "displayScale") }
    }
    @Published var streamPosition: StreamPosition {
        didSet { defaults.set(streamPosition.rawValue, forKey: "streamPosition") }
    }

    // MARK: - Computed Color Properties
    var cardBackgroundColor: Color { Color(hex: cardBackgroundColorHex) ?? .gray }
    var cardBorderColor: Color { Color(hex: cardBorderColorHex) ?? .gray }
    var cardShadowColor: Color { Color(hex: cardShadowColorHex) ?? .black }
    var buttonPrimaryColor: Color { Color(hex: buttonPrimaryColorHex) ?? .blue }
    var buttonSecondaryColor: Color { Color(hex: buttonSecondaryColorHex) ?? .cyan }
    var buttonTextColor: Color { Color(hex: buttonTextColorHex) ?? .white }
    var buttonHoverColor: Color { Color(hex: buttonHoverColorHex) ?? .blue }
    var tabBarColor: Color { Color(hex: tabBarColorHex) ?? .gray }
    var tabBarActiveColor: Color { Color(hex: tabBarActiveColorHex) ?? .blue }
    var tabBarInactiveColor: Color { Color(hex: tabBarInactiveColorHex) ?? .gray }
    var primaryTextColor: Color { Color(hex: primaryTextColorHex) ?? .white }
    var secondaryTextColor: Color { Color(hex: secondaryTextColorHex) ?? .gray }
    var tertiaryTextColor: Color { Color(hex: tertiaryTextColorHex) ?? .gray }
    var gamingAccentColor: Color { Color(hex: gamingAccentColorHex) ?? .red }
    var chatAccentColor: Color { Color(hex: chatAccentColorHex) ?? .purple }
    var analyticsAccentColor: Color { Color(hex: analyticsAccentColorHex) ?? .green }
    var incomeAccentColor: Color { Color(hex: incomeAccentColorHex) ?? .yellow }
    var calendarAccentColor: Color { Color(hex: calendarAccentColorHex) ?? .orange }
    var settingsAccentColor: Color { Color(hex: settingsAccentColorHex) ?? .cyan }
    var glassTintColor: Color { Color(hex: glassTintColorHex) ?? .white }
    var gridBackgroundColor: Color { Color(hex: gridBackgroundColorHex) ?? .black }
    var gridLineColor: Color { Color(hex: gridLineColorHex) ?? .gray }
    var backgroundGradientStart: Color { Color(hex: backgroundGradientStartHex) ?? .black }
    var backgroundGradientEnd: Color { Color(hex: backgroundGradientEndHex) ?? .blue }
    var backgroundSolidColor: Color { Color(hex: backgroundSolidColorHex) ?? .black }

    private init() {
        // Load saved values or use defaults
        self.cardBackgroundColorHex = defaults.string(forKey: "cardBackgroundColorHex") ?? "#1C1C1E"
        self.cardOpacity = defaults.double(forKey: "cardOpacity", default: 0.9)
        self.cardTransparency = defaults.double(forKey: "cardTransparency", default: 0.1)
        self.cardBorderColorHex = defaults.string(forKey: "cardBorderColorHex") ?? "#3A3A3C"
        self.cardBorderWidth = defaults.double(forKey: "cardBorderWidth", default: 1.0)
        self.cardCornerRadius = defaults.double(forKey: "cardCornerRadius", default: 12.0)
        self.cardBlur = defaults.bool(forKey: "cardBlur", default: true)
        self.cardShadowColorHex = defaults.string(forKey: "cardShadowColorHex") ?? "#000000"
        self.cardShadowRadius = defaults.double(forKey: "cardShadowRadius", default: 10.0)
        self.cardShadowOpacity = defaults.double(forKey: "cardShadowOpacity", default: 0.3)

        self.buttonPrimaryColorHex = defaults.string(forKey: "buttonPrimaryColorHex") ?? "#007AFF"
        self.buttonSecondaryColorHex = defaults.string(forKey: "buttonSecondaryColorHex") ?? "#5AC8FA"
        self.buttonTextColorHex = defaults.string(forKey: "buttonTextColorHex") ?? "#FFFFFF"
        self.buttonHoverColorHex = defaults.string(forKey: "buttonHoverColorHex") ?? "#0051D5"
        self.buttonOpacity = defaults.double(forKey: "buttonOpacity", default: 1.0)
        self.buttonCornerRadius = defaults.double(forKey: "buttonCornerRadius", default: 8.0)

        self.tabBarColorHex = defaults.string(forKey: "tabBarColorHex") ?? "#2C2C2E"
        self.tabBarOpacity = defaults.double(forKey: "tabBarOpacity", default: 0.95)
        self.tabBarTransparency = defaults.double(forKey: "tabBarTransparency", default: 0.05)
        self.tabBarActiveColorHex = defaults.string(forKey: "tabBarActiveColorHex") ?? "#007AFF"
        self.tabBarInactiveColorHex = defaults.string(forKey: "tabBarInactiveColorHex") ?? "#8E8E93"

        self.primaryTextColorHex = defaults.string(forKey: "primaryTextColorHex") ?? "#FFFFFF"
        self.secondaryTextColorHex = defaults.string(forKey: "secondaryTextColorHex") ?? "#8E8E93"
        self.tertiaryTextColorHex = defaults.string(forKey: "tertiaryTextColorHex") ?? "#636366"

        self.gamingAccentColorHex = defaults.string(forKey: "gamingAccentColorHex") ?? "#FF2D55"
        self.chatAccentColorHex = defaults.string(forKey: "chatAccentColorHex") ?? "#5856D6"
        self.analyticsAccentColorHex = defaults.string(forKey: "analyticsAccentColorHex") ?? "#34C759"
        self.incomeAccentColorHex = defaults.string(forKey: "incomeAccentColorHex") ?? "#FFD60A"
        self.calendarAccentColorHex = defaults.string(forKey: "calendarAccentColorHex") ?? "#FF9500"
        self.settingsAccentColorHex = defaults.string(forKey: "settingsAccentColorHex") ?? "#5AC8FA"

        self.glassIntensity = defaults.double(forKey: "glassIntensity", default: 0.8)
        self.glassBlurRadius = defaults.double(forKey: "glassBlurRadius", default: 20.0)
        self.glassSaturation = defaults.double(forKey: "glassSaturation", default: 1.8)
        self.glassTintColorHex = defaults.string(forKey: "glassTintColorHex") ?? "#FFFFFF"
        self.glassTintOpacity = defaults.double(forKey: "glassTintOpacity", default: 0.1)

        self.gridBackgroundColorHex = defaults.string(forKey: "gridBackgroundColorHex") ?? "#000000"
        self.gridLineColorHex = defaults.string(forKey: "gridLineColorHex") ?? "#3A3A3C"
        self.gridLineOpacity = defaults.double(forKey: "gridLineOpacity", default: 0.3)
        self.gridSpacing = defaults.double(forKey: "gridSpacing", default: 16.0)

        self.animationsEnabled = defaults.bool(forKey: "animationsEnabled", default: true)
        self.transitionDuration = defaults.double(forKey: "transitionDuration", default: 0.3)

        let backgroundTypeRaw = defaults.string(forKey: "backgroundType") ?? BackgroundType.solid.rawValue
        self.backgroundType = BackgroundType(rawValue: backgroundTypeRaw) ?? .solid
        self.backgroundImagePath = defaults.string(forKey: "backgroundImagePath")
        self.backgroundGradientStartHex = defaults.string(forKey: "backgroundGradientStartHex") ?? "#000000"
        self.backgroundGradientEndHex = defaults.string(forKey: "backgroundGradientEndHex") ?? "#0051D5"
        self.backgroundSolidColorHex = defaults.string(forKey: "backgroundSolidColorHex") ?? "#000000"

        self.windowAlwaysOnTop = defaults.bool(forKey: "windowAlwaysOnTop", default: false)
        self.hideDockIcon = defaults.bool(forKey: "hideDockIcon", default: false)
        self.windowOpacity = defaults.double(forKey: "windowOpacity", default: 1.0)
        self.displayScale = defaults.double(forKey: "displayScale", default: 1.0)
        let streamPositionRaw = defaults.string(forKey: "streamPosition") ?? StreamPosition.topRight.rawValue
        self.streamPosition = StreamPosition(rawValue: streamPositionRaw) ?? .topRight
    }

    // MARK: - Reset Methods
    public func resetToDefaults() {
        // Cards
        cardBackgroundColorHex = "#1C1C1E"
        cardOpacity = 0.9
        cardTransparency = 0.1
        cardBorderColorHex = "#3A3A3C"
        cardBorderWidth = 1.0
        cardCornerRadius = 12.0
        cardBlur = true
        cardShadowColorHex = "#000000"
        cardShadowRadius = 10.0
        cardShadowOpacity = 0.3

        // Buttons
        buttonPrimaryColorHex = "#007AFF"
        buttonSecondaryColorHex = "#5AC8FA"
        buttonTextColorHex = "#FFFFFF"
        buttonHoverColorHex = "#0051D5"
        buttonOpacity = 1.0
        buttonCornerRadius = 8.0

        // Tab Bar
        tabBarColorHex = "#2C2C2E"
        tabBarOpacity = 0.95
        tabBarTransparency = 0.05
        tabBarActiveColorHex = "#007AFF"
        tabBarInactiveColorHex = "#8E8E93"

        // Text
        primaryTextColorHex = "#FFFFFF"
        secondaryTextColorHex = "#8E8E93"
        tertiaryTextColorHex = "#636366"

        // Accents
        gamingAccentColorHex = "#FF2D55"
        chatAccentColorHex = "#5856D6"
        analyticsAccentColorHex = "#34C759"
        incomeAccentColorHex = "#FFD60A"
        calendarAccentColorHex = "#FF9500"
        settingsAccentColorHex = "#5AC8FA"

        // Glass
        glassIntensity = 0.8
        glassBlurRadius = 20.0
        glassSaturation = 1.8
        glassTintColorHex = "#FFFFFF"
        glassTintOpacity = 0.1

        // Grid
        gridBackgroundColorHex = "#000000"
        gridLineColorHex = "#3A3A3C"
        gridLineOpacity = 0.3
        gridSpacing = 16.0

        // Animations
        animationsEnabled = true
        transitionDuration = 0.3

        // Background
        backgroundType = .solid
        backgroundImagePath = nil
        backgroundGradientStartHex = "#000000"
        backgroundGradientEndHex = "#0051D5"
        backgroundSolidColorHex = "#000000"

        // Desktop
        windowAlwaysOnTop = false
        hideDockIcon = false
        windowOpacity = 1.0
        displayScale = 1.0
        streamPosition = .topRight
    }

    // MARK: - Preset Themes
    public func applyPresetTheme(_ preset: ThemePreset) {
        switch preset {
        case .darkPro:
            applyDarkProTheme()
        case .neonGamer:
            applyNeonGamerTheme()
        case .pastelDream:
            applyPastelDreamTheme()
        case .cyberpunk:
            applyCyberpunkTheme()
        case .minimalist:
            applyMinimalistTheme()
        }
    }

    private func applyDarkProTheme() {
        cardBackgroundColorHex = "#1C1C1E"
        cardBorderColorHex = "#48484A"
        buttonPrimaryColorHex = "#0A84FF"
        primaryTextColorHex = "#FFFFFF"
        glassIntensity = 0.7
        backgroundType = .gradient
        backgroundGradientStartHex = "#000000"
        backgroundGradientEndHex = "#1C1C1E"
    }

    private func applyNeonGamerTheme() {
        cardBackgroundColorHex = "#0A0E27"
        cardBorderColorHex = "#FF00FF"
        buttonPrimaryColorHex = "#00FFFF"
        primaryTextColorHex = "#FFFFFF"
        glassIntensity = 0.9
        glassBlurRadius = 30.0
        glassTintColorHex = "#FF00FF"
        glassTintOpacity = 0.2
        backgroundType = .gradient
        backgroundGradientStartHex = "#0A0E27"
        backgroundGradientEndHex = "#FF00FF"
    }

    private func applyPastelDreamTheme() {
        cardBackgroundColorHex = "#FFE5F1"
        cardBorderColorHex = "#FFB3D9"
        buttonPrimaryColorHex = "#FF6BB3"
        primaryTextColorHex = "#4A4A4A"
        secondaryTextColorHex = "#7A7A7A"
        glassIntensity = 0.4
        glassTintColorHex = "#FFB3D9"
        backgroundType = .gradient
        backgroundGradientStartHex = "#FFE5F1"
        backgroundGradientEndHex = "#E5CCFF"
    }

    private func applyCyberpunkTheme() {
        cardBackgroundColorHex = "#0D0221"
        cardBorderColorHex = "#FFEE00"
        buttonPrimaryColorHex = "#FF006E"
        buttonSecondaryColorHex = "#FFEE00"
        primaryTextColorHex = "#FFFFFF"
        glassIntensity = 0.85
        glassBlurRadius = 25.0
        glassTintColorHex = "#FF006E"
        glassTintOpacity = 0.15
        backgroundType = .gradient
        backgroundGradientStartHex = "#0D0221"
        backgroundGradientEndHex = "#FF006E"
    }

    private func applyMinimalistTheme() {
        cardBackgroundColorHex = "#FFFFFF"
        cardBorderColorHex = "#E5E5E5"
        cardBlur = false
        buttonPrimaryColorHex = "#000000"
        buttonTextColorHex = "#FFFFFF"
        primaryTextColorHex = "#000000"
        secondaryTextColorHex = "#666666"
        glassIntensity = 0.0
        backgroundType = .solid
        backgroundSolidColorHex = "#FAFAFA"
    }
}

// MARK: - Supporting Types
public enum BackgroundType: String, CaseIterable {
    case solid = "solid"
    case gradient = "gradient"
    case image = "image"
}

public enum StreamPosition: String, CaseIterable {
    case topLeft = "topLeft"
    case topRight = "topRight"
    case bottomLeft = "bottomLeft"
    case bottomRight = "bottomRight"
}

public enum ThemePreset: String, CaseIterable {
    case darkPro = "Dark Pro"
    case neonGamer = "Neon Gamer"
    case pastelDream = "Pastel Dream"
    case cyberpunk = "Cyberpunk"
    case minimalist = "Minimalist"
}

// MARK: - Extensions
extension UserDefaults {
    func double(forKey key: String, default defaultValue: Double) -> Double {
        if object(forKey: key) != nil {
            return double(forKey: key)
        }
        return defaultValue
    }

    func bool(forKey key: String, default defaultValue: Bool) -> Bool {
        if object(forKey: key) != nil {
            return bool(forKey: key)
        }
        return defaultValue
    }
}

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    func toHex() -> String? {
        guard let components = NSColor(self).cgColor.components else { return nil }

        let r = Int(components[0] * 255.0)
        let g = Int(components[1] * 255.0)
        let b = Int(components[2] * 255.0)

        return String(format: "#%02X%02X%02X", r, g, b)
    }
}