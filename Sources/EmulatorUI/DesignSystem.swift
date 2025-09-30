import SwiftUI

/// Professional Design System following NN/g Usability Principles
/// Provides consistent spacing, colors, typography, and components
public enum DesignSystem {

    // MARK: - Spacing Scale

    public enum Spacing {
        /// 4pt - Minimal spacing
        public static let xs: CGFloat = 4
        /// 8pt - Small spacing
        public static let sm: CGFloat = 8
        /// 12pt - Default spacing
        public static let md: CGFloat = 12
        /// 16pt - Medium-large spacing
        public static let lg: CGFloat = 16
        /// 20pt - Large spacing
        public static let xl: CGFloat = 20
        /// 24pt - Extra large spacing
        public static let xxl: CGFloat = 24
        /// 32pt - Section spacing
        public static let section: CGFloat = 32
    }

    // MARK: - Corner Radius

    public enum Radius {
        /// 4pt - Minimal radius
        public static let sm: CGFloat = 4
        /// 6pt - Small radius for chips
        public static let md: CGFloat = 6
        /// 8pt - Default radius for cards
        public static let lg: CGFloat = 8
        /// 10pt - Large radius for covers
        public static let xl: CGFloat = 10
        /// 12pt - Extra large radius
        public static let xxl: CGFloat = 12
    }

    // MARK: - Typography

    public enum Typography {
        public static let largeTitle = Font.system(size: 34, weight: .bold)
        public static let title = Font.system(size: 24, weight: .bold)
        public static let title2 = Font.system(size: 20, weight: .semibold)
        public static let headline = Font.system(size: 17, weight: .semibold)
        public static let body = Font.system(size: 15, weight: .regular)
        public static let callout = Font.system(size: 13, weight: .medium)
        public static let caption = Font.system(size: 12, weight: .regular)
        public static let caption2 = Font.system(size: 11, weight: .regular)
    }

    // MARK: - Colors (Semantic)

    public enum Colors {
        // Primary Actions
        public static let primary = Color.accentColor
        public static let primaryHover = Color.accentColor.opacity(0.8)

        // Status Colors
        public static let success = Color.green
        public static let warning = Color.orange
        public static let error = Color.red
        public static let info = Color.blue

        // Recording State
        public static let recording = Color.red

        // Backgrounds
        public static let background = Color(NSColor.controlBackgroundColor)
        public static let surface = Color(NSColor.windowBackgroundColor)
        public static let surfaceSecondary = Color.gray.opacity(0.1)

        // Text
        public static let textPrimary = Color.primary
        public static let textSecondary = Color.secondary
        public static let textTertiary = Color(NSColor.tertiaryLabelColor)

        // Borders
        public static let border = Color.gray.opacity(0.2)
        public static let borderSecondary = Color.gray.opacity(0.1)

        // Overlays
        public static let overlay = Color.black.opacity(0.6)
        public static let divider = Color.gray.opacity(0.2)
    }

    // MARK: - Shadows

    public enum Shadow {
        public static let small = (radius: CGFloat(2), x: CGFloat(0), y: CGFloat(1))
        public static let medium = (radius: CGFloat(4), x: CGFloat(0), y: CGFloat(2))
        public static let large = (radius: CGFloat(8), x: CGFloat(0), y: CGFloat(4))
    }

    // MARK: - Component Sizes

    public enum Size {
        // Button Heights
        public static let buttonSmall: CGFloat = 28
        public static let buttonMedium: CGFloat = 36
        public static let buttonLarge: CGFloat = 44

        // Icon Sizes
        public static let iconSmall: CGFloat = 16
        public static let iconMedium: CGFloat = 20
        public static let iconLarge: CGFloat = 24

        // Control Panel
        public static let controlPanelHeight: CGFloat = 60
        public static let toolbarHeight: CGFloat = 48
    }

    // MARK: - Animation Durations

    public enum Duration {
        public static let fast: Double = 0.15
        public static let medium: Double = 0.25
        public static let slow: Double = 0.35
    }
}

// MARK: - View Extensions

public extension View {
    /// Apply consistent card styling
    func cardStyle() -> some View {
        self
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.surface)
            .cornerRadius(DesignSystem.Radius.lg)
            .shadow(radius: DesignSystem.Shadow.small.radius)
    }

    /// Apply surface container styling
    func surfaceStyle() -> some View {
        self
            .background(DesignSystem.Colors.background)
            .cornerRadius(DesignSystem.Radius.md)
    }

    /// Apply consistent button styling with proper feedback
    func actionButtonStyle(isDestructive: Bool = false) -> some View {
        self
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(isDestructive ? DesignSystem.Colors.error : DesignSystem.Colors.primary)
    }
}

// MARK: - Status Badge Component

public struct StatusBadge: View {
    let text: String
    let color: Color
    let icon: String

    public init(text: String, color: Color, icon: String) {
        self.text = text
        self.color = color
        self.icon = icon
    }

    public var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: DesignSystem.Size.iconSmall))
            Text(text)
                .font(DesignSystem.Typography.caption)
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(color.opacity(0.15))
        .foregroundColor(color)
        .cornerRadius(DesignSystem.Radius.md)
    }
}

// MARK: - Icon Button Component

public struct IconButton: View {
    let icon: String
    let tooltip: String
    let action: () -> Void
    var isDestructive: Bool = false

    public init(icon: String, tooltip: String, isDestructive: Bool = false, action: @escaping () -> Void) {
        self.icon = icon
        self.tooltip = tooltip
        self.isDestructive = isDestructive
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: DesignSystem.Size.iconMedium))
                .frame(width: DesignSystem.Size.buttonMedium, height: DesignSystem.Size.buttonMedium)
        }
        .buttonStyle(.bordered)
        .help(tooltip)
        .foregroundColor(isDestructive ? DesignSystem.Colors.error : nil)
    }
}

// MARK: - Section Header Component

public struct DSectionHeader: View {
    let title: String
    var action: (() -> Void)? = nil
    var actionIcon: String? = nil
    var actionLabel: String? = nil

    public init(title: String, action: (() -> Void)? = nil, actionIcon: String? = nil, actionLabel: String? = nil) {
        self.title = title
        self.action = action
        self.actionIcon = actionIcon
        self.actionLabel = actionLabel
    }

    public var body: some View {
        HStack {
            Text(title)
                .font(DesignSystem.Typography.headline)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Spacer()

            if let action = action, let icon = actionIcon, let label = actionLabel {
                Button(action: action) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: icon)
                        Text(label)
                    }
                    .font(DesignSystem.Typography.callout)
                }
                .buttonStyle(BorderedButtonStyle())
            }
        }
    }
}

// MARK: - Empty State Placeholder Component

public struct EmptyStatePlaceholder: View {
    let icon: String
    let title: String
    let message: String
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil

    public init(icon: String, title: String, message: String, actionLabel: String? = nil, action: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionLabel = actionLabel
        self.action = action
    }

    public var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(DesignSystem.Colors.textTertiary)

            VStack(spacing: DesignSystem.Spacing.xs) {
                Text(title)
                    .font(DesignSystem.Typography.title2)
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                Text(message)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                    .multilineTextAlignment(.center)
            }

            if let actionLabel = actionLabel, let action = action {
                Button(action: action) {
                    Text(actionLabel)
                        .font(DesignSystem.Typography.callout)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DesignSystem.Spacing.xxl)
    }
}