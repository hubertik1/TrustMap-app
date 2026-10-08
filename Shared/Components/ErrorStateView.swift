import SwiftUI

struct ErrorStateView: View {
    let message: String
    var retryTitle: String = L10n.tryAgain
    var retryAction: (() -> Void)?

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.orange)
                    .frame(width: 64, height: 64)
                    .background(
                        Circle()
                            .fill(Color.orange.opacity(0.12))
                    )
                    .accessibilityHidden(true)

                Text(L10n.somethingWentWrong)
                    .font(.headline)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if let retryAction {
                    Button(retryTitle, action: retryAction)
                        .buttonStyle(.borderedProminent)
                        .accessibilityLabel(retryTitle)
                }
            }
            .frame(maxWidth: 320)
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
            .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 18, y: 8)
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ErrorStateView(message: "We couldn’t load your map data.")
}
