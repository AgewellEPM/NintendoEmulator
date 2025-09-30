import SwiftUI

extension View {
    @ViewBuilder
    func if14Plus<Content: View>(@ViewBuilder content: (Self) -> Content) -> some View {
        content(self)
    }
}