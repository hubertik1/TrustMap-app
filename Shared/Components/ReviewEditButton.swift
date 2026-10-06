import SwiftUI

struct ReviewEditButton<Content: View>: View {
    let action: (() -> Void)?
    private let content: Content

    init(action: (() -> Void)?, @ViewBuilder content: () -> Content) {
        self.action = action
        self.content = content()
    }

    @ViewBuilder
    var body: some View {
        if let action {
            Button(action: action) {
                content
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit review")
        } else {
            content
        }
    }
}
