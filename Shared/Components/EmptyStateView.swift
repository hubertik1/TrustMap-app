import SwiftUI

struct EmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 64, height: 64)
                    .background(
                        Circle()
                            .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    )
                    .accessibilityHidden(true)

                Text(title)
                    .font(.headline)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 320)
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
            .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 18, y: 8)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title). \(message)")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

struct ProductEmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String
    let primaryActionTitle: String
    let onPrimaryAction: () -> Void
    let secondaryActionTitle: String?
    let onSecondaryAction: (() -> Void)?

    init(
        title: String,
        message: String,
        systemImage: String,
        primaryActionTitle: String,
        onPrimaryAction: @escaping () -> Void,
        secondaryActionTitle: String? = nil,
        onSecondaryAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.primaryActionTitle = primaryActionTitle
        self.onPrimaryAction = onPrimaryAction
        self.secondaryActionTitle = secondaryActionTitle
        self.onSecondaryAction = onSecondaryAction
    }

    var body: some View {
        VStack {
            Spacer(minLength: 24)

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 72, height: 72)

                    Image(systemName: systemImage)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                }

                VStack(spacing: 8) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 12) {
                    Button(action: onPrimaryAction) {
                        Text(primaryActionTitle)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityLabel(primaryActionTitle)

                    if let secondaryActionTitle, let onSecondaryAction {
                        Button(secondaryActionTitle, action: onSecondaryAction)
                            .font(.subheadline.weight(.semibold))
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.accentColor)
                            .accessibilityLabel(secondaryActionTitle)
                    }
                }
            }
            .frame(maxWidth: 340)
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.65))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.03), radius: 14, y: 6)
            .padding(.horizontal, 24)

            Spacer(minLength: 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    EmptyStateView(
        title: "No Reviews Yet",
        message: "Places you and your friends rate will appear here.",
        systemImage: "sparkles.rectangle.stack"
    )
}
