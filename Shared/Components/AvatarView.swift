import SwiftUI

struct AvatarView: View {
    let name: String
    var size: CGFloat = 40

    private var initials: String {
        let parts = name.split(separator: " ")
        let characters = parts.prefix(2).compactMap(\.first)
        return characters.isEmpty ? "TM" : String(characters)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.15))

            Text(initials.uppercased())
                .font(.system(size: size * 0.36, weight: .semibold))
                .foregroundStyle(Color.accentColor)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

#Preview {
    AvatarView(name: "Taylor Morgan", size: 56)
}
