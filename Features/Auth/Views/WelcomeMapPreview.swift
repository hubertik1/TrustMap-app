import MapKit
import SwiftUI

/// An illustrative map rendered with real UI text so it follows the app language.
struct WelcomeMapPreview: View {
    private static let region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7593, longitude: -122.4128),
        span: MKCoordinateSpan(latitudeDelta: 0.006, longitudeDelta: 0.006)
    )

    var body: some View {
        Map(initialPosition: .region(Self.region), interactionModes: []) {
            Annotation("Caffè Aurora", coordinate: CLLocationCoordinate2D(latitude: 37.7606, longitude: -122.4119)) {
                ratingPin(4, color: .green)
            }
            Annotation("Bistro Verde", coordinate: CLLocationCoordinate2D(latitude: 37.7596, longitude: -122.4146)) {
                ratingPin(5, color: .orange)
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll, showsTraffic: false))
        .mapControls {}
        .allowsHitTesting(false)
        .aspectRatio(1, contentMode: .fit)
        .overlay(alignment: .bottom) {
            exampleReview
                .padding(12)
        }
        .accessibilityHidden(true)
    }

    private func ratingPin(_ rating: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "fork.knife")
            Text(RatingDisplayFormatter.rating(rating))
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(.white)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(color, in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
    }

    private var exampleReview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Circle()
                    .fill(.green.opacity(0.65))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Text("N")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                Text("Caffè Aurora")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            Text(L10n.welcomeExampleReview)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            HStack(spacing: 8) {
                Text(L10n.trustedByFriends(3))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                HStack(spacing: -4) {
                    exampleAvatar("AL", color: .orange)
                    exampleAvatar("NC", color: .mint)
                    exampleAvatar("ME", color: .blue)
                }
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
    }

    private func exampleAvatar(_ initials: String, color: Color) -> some View {
        Circle()
            .fill(color.opacity(0.65))
            .frame(width: 28, height: 28)
            .overlay {
                Text(initials)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .overlay {
                Circle().strokeBorder(.background, lineWidth: 2)
            }
    }
}
