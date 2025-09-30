import SwiftUI

// MARK: - Semantic Color System
public struct DashboardTheme {
    // Background Colors (Dark Theme)
    static let backgroundPrimary = Color(red: 0.05, green: 0.05, blue: 0.08)
    static let backgroundSecondary = Color(red: 0.08, green: 0.08, blue: 0.12)
    static let backgroundTertiary = Color(red: 0.12, green: 0.12, blue: 0.16)
    static let backgroundElevated = Color.white.opacity(0.05)
    static let backgroundOverlay = Color.black.opacity(0.4)

    // Surface Colors
    static let surfaceCard = Color.white.opacity(0.03)
    static let surfaceCardHover = Color.white.opacity(0.06)
    static let surfaceCardPressed = Color.white.opacity(0.08)
    static let surfaceBorder = Color.white.opacity(0.1)

    // Text Colors (Semantic)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)
    static let textTertiary = Color.white.opacity(0.5)
    static let textDisabled = Color.white.opacity(0.3)
    static let textInverse = Color.black

    // Status Colors (Semantic)
    static let statusLive = Color.red
    static let statusSuccess = Color.green
    static let statusWarning = Color.orange
    static let statusError = Color.red
    static let statusInfo = Color.blue
    static let statusOffline = Color.gray

    // Interactive Colors
    static let interactivePrimary = Color.blue
    static let interactiveSecondary = Color.purple
    static let interactiveHover = Color.blue.opacity(0.8)
    static let interactivePressed = Color.blue.opacity(0.6)
    static let interactiveFocus = Color.blue.opacity(0.3)

    // Metric Colors (Data Visualization)
    static let metricPositive = Color.green
    static let metricNegative = Color.red
    static let metricNeutral = Color.gray
    static let metricHighlight = Color.yellow

    // Platform Brand Colors
    static let platformTwitch = Color(red: 0.57, green: 0.27, blue: 0.87)
    static let platformYouTube = Color.red
    static let platformTikTok = Color.black
    static let platformKick = Color(red: 0.0, green: 0.87, blue: 0.44)

    // Accessibility
    static let focusRing = Color.blue.opacity(0.5)
    static let highContrast = Color.white

    // Spacing System (8pt grid)
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // Typography
    enum Typography {
        static let heroSize: CGFloat = 48
        static let titleSize: CGFloat = 32
        static let headingSize: CGFloat = 24
        static let bodySize: CGFloat = 16
        static let captionSize: CGFloat = 14
        static let microSize: CGFloat = 12
    }

    // Animation
    enum Animation {
        static let quickDuration: Double = 0.2
        static let standardDuration: Double = 0.3
        static let slowDuration: Double = 0.5
        static let springResponse: Double = 0.6
        static let springDamping: Double = 0.8
    }

    // Border Radius
    enum Radius {
        static let small: CGFloat = 4
        static let medium: CGFloat = 8
        static let large: CGFloat = 12
        static let xlarge: CGFloat = 16
        static let pill: CGFloat = 999
    }

    // Shadow Styles
    struct ShadowStyle {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat

        static func small(_ color: Color = .black) -> ShadowStyle {
            ShadowStyle(color: color.opacity(0.1), radius: 2, x: 0, y: 1)
        }

        static func medium(_ color: Color = .black) -> ShadowStyle {
            ShadowStyle(color: color.opacity(0.15), radius: 4, x: 0, y: 2)
        }

        static func large(_ color: Color = .black) -> ShadowStyle {
            ShadowStyle(color: color.opacity(0.2), radius: 8, x: 0, y: 4)
        }

        static func elevation(_ level: Int) -> ShadowStyle {
            switch level {
            case 1: return small()
            case 2: return medium()
            case 3: return large()
            default: return small()
            }
        }
    }
}

// MARK: - Accessibility Helpers
public struct AccessibilityHelpers {
    // WCAG 2.1 Contrast Ratios
    static func meetsContrastRatio(foreground: Color, background: Color, isLargeText: Bool = false) -> Bool {
        // Large text: 3:1, Normal text: 4.5:1
        _ = isLargeText ? 3.0 : 4.5
        // Implementation would calculate actual contrast ratio
        return true // Placeholder
    }

    // Touch Target Sizes (44x44 minimum for iOS/macOS)
    static let minimumTouchTarget: CGFloat = 44

    // Focus Indicator Styles
    static func focusStyle() -> some ViewModifier {
        FocusRingModifier()
    }
}

// MARK: - View Modifiers
struct FocusRingModifier: ViewModifier {
    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: DashboardTheme.Radius.medium)
                    .stroke(DashboardTheme.focusRing, lineWidth: 2)
                    .opacity(isFocused ? 1 : 0)
                    .animation(.easeInOut(duration: DashboardTheme.Animation.quickDuration), value: isFocused)
            )
            .focused($isFocused)
    }
}

struct CardStyle: ViewModifier {
    var isHovering: Bool = false
    var isPressed: Bool = false
    var elevation: Int = 1

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: DashboardTheme.Radius.large)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DashboardTheme.Radius.large)
                    .stroke(DashboardTheme.surfaceBorder, lineWidth: 1)
            )
            .shadow(
                color: shadowColor,
                radius: shadowRadius,
                x: 0,
                y: shadowY
            )
            .scaleEffect(isPressed ? 0.98 : (isHovering ? 1.02 : 1.0))
            .animation(.spring(response: DashboardTheme.Animation.springResponse, dampingFraction: DashboardTheme.Animation.springDamping), value: isHovering)
            .animation(.spring(response: DashboardTheme.Animation.springResponse, dampingFraction: DashboardTheme.Animation.springDamping), value: isPressed)
    }

    private var backgroundColor: Color {
        if isPressed {
            return DashboardTheme.surfaceCardPressed
        } else if isHovering {
            return DashboardTheme.surfaceCardHover
        } else {
            return DashboardTheme.surfaceCard
        }
    }

    private var shadowColor: Color {
        Color.black.opacity(elevation == 1 ? 0.1 : elevation == 2 ? 0.15 : 0.2)
    }

    private var shadowRadius: CGFloat {
        CGFloat(elevation * 2)
    }

    private var shadowY: CGFloat {
        CGFloat(elevation)
    }
}

// MARK: - Extensions
extension View {
    func dashboardCard(isHovering: Bool = false, isPressed: Bool = false, elevation: Int = 1) -> some View {
        self.modifier(CardStyle(isHovering: isHovering, isPressed: isPressed, elevation: elevation))
    }

    func semanticText(_ level: TextLevel) -> some View {
        self.foregroundColor(level.color)
            .font(level.font)
    }

    func accessibleTouchTarget() -> some View {
        self.frame(minWidth: AccessibilityHelpers.minimumTouchTarget, minHeight: AccessibilityHelpers.minimumTouchTarget)
    }
}

enum TextLevel {
    case primary
    case secondary
    case tertiary
    case disabled
    case error
    case success

    var color: Color {
        switch self {
        case .primary: return DashboardTheme.textPrimary
        case .secondary: return DashboardTheme.textSecondary
        case .tertiary: return DashboardTheme.textTertiary
        case .disabled: return DashboardTheme.textDisabled
        case .error: return DashboardTheme.statusError
        case .success: return DashboardTheme.statusSuccess
        }
    }

    var font: Font {
        switch self {
        case .primary: return .body
        case .secondary: return .subheadline
        case .tertiary: return .caption
        case .disabled: return .caption
        case .error: return .caption
        case .success: return .caption
        }
    }
}

// MARK: - Responsive Grid System
struct ResponsiveGrid<Content: View>: View {
    let columns: Int
    let spacing: CGFloat
    let content: () -> Content

    @State private var availableWidth: CGFloat = 0

    init(columns: Int = 3, spacing: CGFloat = DashboardTheme.Spacing.md, @ViewBuilder content: @escaping () -> Content) {
        self.columns = columns
        self.spacing = spacing
        self.content = content
    }

    var adaptiveColumns: [GridItem] {
        let minWidth: CGFloat = 250
        let count = max(1, Int(availableWidth / minWidth))
        return Array(repeating: GridItem(.flexible(), spacing: spacing), count: min(count, columns))
    }

    var body: some View {
        GeometryReader { geometry in
            LazyVGrid(columns: adaptiveColumns, spacing: spacing) {
                content()
            }
            .onAppear {
                availableWidth = geometry.size.width
            }
            .onChange(of: geometry.size.width) { newWidth in
                availableWidth = newWidth
            }
        }
    }
}

// MARK: - Progressive Disclosure Component
struct ProgressiveDisclosure<Summary: View, Details: View>: View {
    let summary: () -> Summary
    let details: () -> Details

    @State private var isExpanded = false
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Summary (Always visible)
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    summary()

                    Spacer()

                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .font(.caption)
                        .foregroundColor(DashboardTheme.textSecondary)
                }
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isHovering = hovering
            }

            // Details (Progressive disclosure)
            if isExpanded {
                details()
                    .padding(.top, DashboardTheme.Spacing.sm)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .scale)
                    ))
            }
        }
        .padding(DashboardTheme.Spacing.md)
        .dashboardCard(isHovering: isHovering)
    }
}

// MARK: - Skeleton Loading
struct SkeletonView: View {
    @State private var isAnimating = false
    let height: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: DashboardTheme.Radius.small)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        DashboardTheme.surfaceCard,
                        DashboardTheme.surfaceCardHover,
                        DashboardTheme.surfaceCard
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: height)
            .offset(x: isAnimating ? 200 : -200)
            .animation(
                Animation.linear(duration: 1.5)
                    .repeatForever(autoreverses: false),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}