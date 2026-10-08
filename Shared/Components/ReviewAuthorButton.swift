import SwiftUI

struct ReviewAuthorButton: View {
    let name: String
    let date: Date
    let font: Font
    let nameColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: PlaceDetailVisualSystem.Metrics.textSpacing) {
                Text(name)
                    .font(font)
                    .foregroundStyle(nameColor)

                Text(date.placeDetailTimestampText)
                    .font(PlaceDetailVisualSystem.Typography.meta)
                    .foregroundStyle(PlaceDetailVisualSystem.Colors.tertiary)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .topLeading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
        .accessibilityHint(L10n.opensThisUserSProfile)
    }
}
