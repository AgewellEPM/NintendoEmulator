import SwiftUI

/// NN/g-Compliant Tab Button with clear visual feedback
struct EnhancedTabButton: View {
    let title: String
    let icon: String
    let tab: ContentViewTab
    @Binding var currentTab: ContentViewTab
    var isPrimary: Bool = false

    private var isSelected: Bool {
        currentTab == tab
    }

    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: DesignSystem.Duration.fast)) {
                currentTab = tab
            }
        }) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: DesignSystem.Size.iconSmall))
                Text(title)
                    .font(DesignSystem.Typography.callout)
            }
            .foregroundColor(foregroundColor)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(backgroundColor)
            .cornerRadius(DesignSystem.Radius.md)
        }
        .buttonStyle(.plain)
        .help(title)
    }

    private var foregroundColor: Color {
        if isPrimary && !isSelected {
            return DesignSystem.Colors.primary
        }
        return isSelected ? .white : Color.primary
    }

    private var backgroundColor: Color {
        if isSelected {
            return isPrimary ? DesignSystem.Colors.success : DesignSystem.Colors.primary
        }
        return isPrimary ? DesignSystem.Colors.primary.opacity(0.1) : Color.clear
    }
}