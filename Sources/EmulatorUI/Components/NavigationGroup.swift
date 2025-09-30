import SwiftUI

/// Simple horizontal grouping wrapper used for top-level navigation clusters
struct NavigationGroup<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            content
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(title))
    }
}

