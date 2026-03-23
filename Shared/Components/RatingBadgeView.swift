import SwiftUI

struct RatingBadgeView: View {
    let rating: Double

    private var color: Color {
        switch rating {
        case 9...:
            return .green
        case 7..<9:
            return .teal
        case 5..<7:
            return .orange
        default:
            return .red
        }
    }

    var body: some View {
        Text(String(format: "%.1f", rating))
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color, in: Capsule())
            .accessibilityLabel("Rating \(rating, specifier: "%.1f") out of 10")
    }
}

#Preview {
    RatingBadgeView(rating: 8.7)
}
