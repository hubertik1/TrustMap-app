import SwiftUI

/// Fictional onboarding artwork; labels remain native and follow the app language.
struct WelcomeMapPreview: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Image("WelcomeScreenMap")
            .resizable()
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                Color.black.opacity(colorScheme == .dark ? 0.12 : 0)
            }
            .overlay {
                GeometryReader { geometry in
                    ZStack {
                        ratingPin(4.0)
                            .position(x: geometry.size.width * 0.18, y: geometry.size.height * 0.18)

                        VStack(spacing: 5) {
                            ratingPin(4.5)
                            Text(verbatim: "Sunday Table")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(.regularMaterial, in: Capsule())
                        }
                        .position(x: geometry.size.width * 0.58, y: geometry.size.height * 0.24)
                    }
                }
            }
            .overlay(alignment: .bottom) {
                WelcomeDemoPlaceCard()
                    .padding(12)
            }
            .allowsHitTesting(false)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityHidden(true)
    }

    private func ratingPin(_ rating: Double) -> some View {
        VStack(spacing: -2) {
            HStack(spacing: 5) {
                Image(systemName: "fork.knife")
                Text(RatingDisplayFormatter.rating(rating))
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(rating.badgeFillColor, in: Capsule())

            Image(systemName: "arrowtriangle.down.fill")
                .font(.caption2)
                .foregroundStyle(rating.badgeFillColor)
        }
        .shadow(color: .black.opacity(0.15), radius: 5, y: 3)
    }
}
