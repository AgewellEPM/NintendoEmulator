import SwiftUI
import EmulatorKit

/// Unified, NN/g-Compliant Components for Entire App
/// These components ensure visual consistency across all views

// MARK: - Unified Card

public struct UnifiedCard<Content: View>: View {
    let title: String?
    let subtitle: String?
    let icon: String?
    let content: Content
    var style: CardStyle = .standard

    public enum CardStyle {
        case standard
        case highlighted
        case warning
        case success
        case error
    }

    public init(
        title: String? = nil,
        subtitle: String? = nil,
        icon: String? = nil,
        style: CardStyle = .standard,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.style = style
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header
            if title != nil || subtitle != nil {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    if let title = title {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            if let icon = icon {
                                Image(systemName: icon)
                                    .font(DesignSystem.Typography.headline)
                                    .foregroundColor(headerColor)
                            }
                            Text(title)
                                .font(DesignSystem.Typography.headline)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                        }
                    }

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
            }

            // Content
            content
        }
        .padding(DesignSystem.Spacing.lg)
        .background(backgroundColor)
        .cornerRadius(DesignSystem.Radius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                .stroke(borderColor, lineWidth: borderWidth)
        )
    }

    private var backgroundColor: Color {
        switch style {
        case .standard:
            return DesignSystem.Colors.surface
        case .highlighted:
            return DesignSystem.Colors.primary.opacity(0.1)
        case .warning:
            return DesignSystem.Colors.warning.opacity(0.1)
        case .success:
            return DesignSystem.Colors.success.opacity(0.1)
        case .error:
            return DesignSystem.Colors.error.opacity(0.1)
        }
    }

    private var borderColor: Color {
        switch style {
        case .standard:
            return DesignSystem.Colors.border
        case .highlighted:
            return DesignSystem.Colors.primary.opacity(0.3)
        case .warning:
            return DesignSystem.Colors.warning.opacity(0.3)
        case .success:
            return DesignSystem.Colors.success.opacity(0.3)
        case .error:
            return DesignSystem.Colors.error.opacity(0.3)
        }
    }

    private var borderWidth: CGFloat {
        style == .standard ? 1 : 2
    }

    private var headerColor: Color {
        switch style {
        case .standard:
            return DesignSystem.Colors.primary
        case .highlighted:
            return DesignSystem.Colors.primary
        case .warning:
            return DesignSystem.Colors.warning
        case .success:
            return DesignSystem.Colors.success
        case .error:
            return DesignSystem.Colors.error
        }
    }
}

// MARK: - Loading Overlay

public struct LoadingOverlay: View {
    let message: String
    var showProgress: Bool = false
    @State private var rotation = 0.0

    public init(message: String, showProgress: Bool = false) {
        self.message = message
        self.showProgress = showProgress
    }

    public var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            // Loading card
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Spinner
                if showProgress {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(1.5)
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 40))
                        .foregroundColor(DesignSystem.Colors.primary)
                        .rotationEffect(.degrees(rotation))
                        .onAppear {
                            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                                rotation = 360
                            }
                        }
                }

                Text(message)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)
            }
            .padding(DesignSystem.Spacing.xxl)
            .background(.ultraThinMaterial)
            .cornerRadius(DesignSystem.Radius.xl)
            .shadow(radius: DesignSystem.Shadow.large.radius)
        }
    }
}

// MARK: - Primary Action Button

public struct PrimaryActionButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    var isDestructive: Bool = false
    var isDisabled: Bool = false

    public init(
        title: String,
        icon: String? = nil,
        isDestructive: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isDestructive = isDestructive
        self.isDisabled = isDisabled
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(DesignSystem.Typography.callout)
                }
                Text(title)
                    .font(DesignSystem.Typography.callout)
                    .fontWeight(.semibold)
            }
            .frame(minWidth: 100)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.sm)
        }
        .buttonStyle(.borderedProminent)
        .tint(isDestructive ? DesignSystem.Colors.error : DesignSystem.Colors.primary)
        .controlSize(.large)
        .disabled(isDisabled)
    }
}

// MARK: - Secondary Action Button

public struct SecondaryActionButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    var isDisabled: Bool = false

    public init(
        title: String,
        icon: String? = nil,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isDisabled = isDisabled
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(DesignSystem.Typography.callout)
                }
                Text(title)
                    .font(DesignSystem.Typography.callout)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
        }
        .buttonStyle(.bordered)
        .disabled(isDisabled)
    }
}

// MARK: - Confirmation Dialog

public struct ConfirmationDialog: View {
    @Binding var isPresented: Bool
    let title: String
    let message: String
    let confirmTitle: String
    let isDestructive: Bool
    let onConfirm: () -> Void

    public init(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        confirmTitle: String = "Confirm",
        isDestructive: Bool = false,
        onConfirm: @escaping () -> Void
    ) {
        self._isPresented = isPresented
        self.title = title
        self.message = message
        self.confirmTitle = confirmTitle
        self.isDestructive = isDestructive
        self.onConfirm = onConfirm
    }

    public var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }

            // Dialog
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                // Title
                HStack {
                    Image(systemName: isDestructive ? "exclamationmark.triangle.fill" : "questionmark.circle.fill")
                        .font(DesignSystem.Typography.title2)
                        .foregroundColor(isDestructive ? DesignSystem.Colors.warning : DesignSystem.Colors.primary)

                    Text(title)
                        .font(DesignSystem.Typography.title2)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }

                // Message
                Text(message)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                // Actions
                HStack(spacing: DesignSystem.Spacing.md) {
                    SecondaryActionButton(title: "Cancel") {
                        isPresented = false
                    }

                    Spacer()

                    PrimaryActionButton(
                        title: confirmTitle,
                        isDestructive: isDestructive
                    ) {
                        onConfirm()
                        isPresented = false
                    }
                }
            }
            .padding(DesignSystem.Spacing.xxl)
            .frame(maxWidth: 400)
            .background(DesignSystem.Colors.surface)
            .cornerRadius(DesignSystem.Radius.xl)
            .shadow(radius: DesignSystem.Shadow.large.radius)
        }
    }
}

// MARK: - Unified Status Indicator

public struct UnifiedStatusIndicator: View {
    let status: StatusType
    let label: String
    var showLabel: Bool = true
    var size: IndicatorSize = .medium

    public enum StatusType {
        case online
        case offline
        case warning
        case error
        case processing

        var color: Color {
            switch self {
            case .online: return DesignSystem.Colors.success
            case .offline: return Color.gray
            case .warning: return DesignSystem.Colors.warning
            case .error: return DesignSystem.Colors.error
            case .processing: return DesignSystem.Colors.info
            }
        }

        var icon: String {
            switch self {
            case .online: return "checkmark.circle.fill"
            case .offline: return "circle"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            case .processing: return "arrow.triangle.2.circlepath"
            }
        }
    }

    public enum IndicatorSize {
        case small, medium, large

        var dotSize: CGFloat {
            switch self {
            case .small: return 6
            case .medium: return 8
            case .large: return 10
            }
        }

        var fontSize: Font {
            switch self {
            case .small: return DesignSystem.Typography.caption2
            case .medium: return DesignSystem.Typography.caption
            case .large: return DesignSystem.Typography.callout
            }
        }
    }

    public init(status: StatusType, label: String, showLabel: Bool = true, size: IndicatorSize = .medium) {
        self.status = status
        self.label = label
        self.showLabel = showLabel
        self.size = size
    }

    public var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Circle()
                .fill(status.color)
                .frame(width: size.dotSize, height: size.dotSize)

            if showLabel {
                Text(label)
                    .font(size.fontSize)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
    }
}

// MARK: - Metric Display Card

public struct MetricDisplayCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String?
    let trend: Trend?
    let color: Color

    public enum Trend {
        case up(String)
        case down(String)
        case neutral(String)

        var icon: String {
            switch self {
            case .up: return "arrow.up.right"
            case .down: return "arrow.down.right"
            case .neutral: return "minus"
            }
        }

        var color: Color {
            switch self {
            case .up: return DesignSystem.Colors.success
            case .down: return DesignSystem.Colors.error
            case .neutral: return Color.gray
            }
        }

        var text: String {
            switch self {
            case .up(let val), .down(let val), .neutral(let val):
                return val
            }
        }
    }

    public init(
        icon: String,
        title: String,
        value: String,
        subtitle: String? = nil,
        trend: Trend? = nil,
        color: Color = DesignSystem.Colors.primary
    ) {
        self.icon = icon
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.trend = trend
        self.color = color
    }

    public var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: DesignSystem.Size.iconLarge))
                .foregroundColor(color)
                .frame(width: 40)

            // Content
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(title)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                HStack(spacing: DesignSystem.Spacing.sm) {
                    Text(value)
                        .font(DesignSystem.Typography.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    if let trend = trend {
                        HStack(spacing: 2) {
                            Image(systemName: trend.icon)
                                .font(DesignSystem.Typography.caption2)
                            Text(trend.text)
                                .font(DesignSystem.Typography.caption2)
                        }
                        .foregroundColor(trend.color)
                    }
                }

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }

            Spacer()
        }
        .padding(DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity)
        .background(DesignSystem.Colors.surface)
        .cornerRadius(DesignSystem.Radius.md)
    }
}