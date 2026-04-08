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
        .accessibilityValue(rating == 0 ? "No rating selected" : "\(rating) out of \(maximumRating)")
    }
}

extension Double {
    var badgeFillColor: Color {
        switch self {
        case 1.0..<2.0:
            return Color(red: 0.86, green: 0.26, blue: 0.21)
        case 2.0..<3.0:
            return Color(red: 0.93, green: 0.52, blue: 0.20)
        case 3.0..<4.0:
            return Color(red: 0.90, green: 0.76, blue: 0.24)
        case 4.0..<4.5:
            return Color(red: 0.42, green: 0.72, blue: 0.31)
        default:
            return Color(red: 0.22, green: 0.56, blue: 0.27)
        }
    }

    var badgeBorderColor: Color {
        switch self {
        case 1.0..<2.0:
            return Color(red: 0.74, green: 0.19, blue: 0.15)
        case 2.0..<3.0:
            return Color(red: 0.82, green: 0.43, blue: 0.15)
        case 3.0..<4.0:
            return Color(red: 0.77, green: 0.63, blue: 0.18)
        case 4.0..<4.5:
            return Color(red: 0.30, green: 0.58, blue: 0.22)
        default:
            return Color(red: 0.16, green: 0.43, blue: 0.21)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        RatingBadgeView(rating: 4.6)
        StarRatingInputView(rating: .constant(4))
    }
}
