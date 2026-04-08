import SwiftUI

struct RatingBadgeView: View {
    let rating: Double

    var body: some View {
        Text(String(format: "%.1f", rating))
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(rating.badgeFillColor, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(rating.badgeBorderColor, lineWidth: 1.5)
            }
            .accessibilityLabel("Rating \(rating, specifier: "%.1f") out of 5")
    }
}

struct StarRatingInputView: View {
    @Binding var rating: Int
    var maximumRating = 5

    var body: some View {
        HStack(spacing: 10) {
            ForEach(1...maximumRating, id: \.self) { star in
                Button {
                    rating = star
                } label: {
                    Image(systemName: star <= rating ? "star.fill" : "star")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(star <= rating ? Color.yellow : Color.secondary.opacity(0.55))
                        .frame(width: 32, height: 32)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(star) star\(star == 1 ? "" : "s")")
                .accessibilityAddTraits(star == rating ? .isSelected : [])
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Rating")
        .accessibilityValue("\(rating) out of \(maximumRating)")
    }
}

extension Double {
    var badgeFillColor: Color {
        switch self {
        case ..<2.0:
            return Color(red: 0.62, green: 0.23, blue: 0.18)
        case ..<3.0:
            return Color(red: 0.79, green: 0.42, blue: 0.17)
        case ..<3.7:
            return Color(red: 0.82, green: 0.65, blue: 0.23)
        case ..<4.4:
            return Color(red: 0.43, green: 0.55, blue: 0.24)
        default:
            return Color(red: 0.18, green: 0.42, blue: 0.24)
        }
    }

    var badgeBorderColor: Color {
        switch self {
        case ..<2.0:
            return Color(red: 0.47, green: 0.16, blue: 0.12)
        case ..<3.0:
            return Color(red: 0.61, green: 0.30, blue: 0.11)
        case ..<3.7:
            return Color(red: 0.65, green: 0.50, blue: 0.15)
        case ..<4.4:
            return Color(red: 0.31, green: 0.42, blue: 0.16)
        default:
            return Color(red: 0.12, green: 0.29, blue: 0.16)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        RatingBadgeView(rating: 4.6)
        StarRatingInputView(rating: .constant(4))
    }
}
