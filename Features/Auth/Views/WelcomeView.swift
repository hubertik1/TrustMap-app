import AuthenticationServices
import SwiftUI

private enum WelcomeLayout {
    static let horizontalContentPadding: CGFloat = 32
}

struct WelcomeView: View {
    @Environment(\.colorScheme) private var colorScheme

    @StateObject private var viewModel: WelcomeViewModel

    init(viewModel: WelcomeViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    private var theme: WelcomeTheme {
        WelcomeTheme(colorScheme: colorScheme)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                WelcomeBackgroundView(theme: theme)

                GeometryReader { geometry in
                    ViewThatFits(in: .vertical) {
                        welcomeContent(allowsFlexibleSpacing: true)
                            .frame(
                                width: geometry.size.width,
                                height: geometry.size.height,
                                alignment: .top
                            )

                        ScrollView(showsIndicators: false) {
                            welcomeContent(allowsFlexibleSpacing: false)
                                .frame(maxWidth: .infinity, alignment: .top)
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                WelcomeCTASection(
                    theme: theme,
                    isSigningIn: viewModel.isSigningIn,
                    isPreviewEnvironment: AppConfiguration.isRunningPreviews,
                    configureRequest: viewModel.configure(_:),
                    handleCompletion: viewModel.handleSignInCompletion(_:)
                )
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    @ViewBuilder
    private func welcomeContent(allowsFlexibleSpacing: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            WelcomeBrandHeader(theme: theme)

            heroSection
                .padding(.top, 22)

            if allowsFlexibleSpacing {
                Spacer(minLength: 24)
            } else {
                WelcomePreviewCard(theme: theme)
                    .padding(.top, 28)
            }

            if allowsFlexibleSpacing {
                WelcomePreviewCard(theme: theme)
            }
        }
        .padding(.horizontal, WelcomeLayout.horizontalContentPadding)
        .padding(.top, 16)
        .padding(.bottom, allowsFlexibleSpacing ? 16 : 32)
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            (
                Text("Keep the places your")
                    .foregroundStyle(.primary) +
                Text("\npeople trust")
                    .foregroundStyle(theme.headlineAccent) +
                Text("\nall in one map.")
                    .foregroundStyle(.primary)
            )
            .font(.system(size: 27, weight: .bold, design: .rounded))
            .tracking(-0.15)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel("Keep the places your people trust all in one map.")

            Text("Save favorite spots, compare notes, and revisit trusted picks from your friends.")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct WelcomeBrandHeader: View {
    let theme: WelcomeTheme

    var body: some View {
        HStack(spacing: 14) {
            Image("TrustMapBrandMark")
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .frame(width: 62, height: 62)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(theme.brandBorder, lineWidth: 1)
                }
                .shadow(color: theme.brandShadow, radius: 18, y: 10)

            VStack(alignment: .leading, spacing: 3) {
                Text("TrustMap")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text("Private recommendations from trusted friends")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
} 

private struct WelcomePreviewCard: View {
    let theme: WelcomeTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image("WelcomeScreenMap")
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(theme.imageStroke, lineWidth: 1)
                }
                .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(theme.cardFill)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(theme.cardStroke, lineWidth: 1)
        }
        .shadow(color: theme.cardShadow, radius: theme.cardShadowRadius, y: 16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Preview of the real TrustMap product showing the welcome map screen.")
    }
}

private struct WelcomeCTASection: View {
    let theme: WelcomeTheme
    let isSigningIn: Bool
    let isPreviewEnvironment: Bool
    let configureRequest: (ASAuthorizationAppleIDRequest) -> Void
    let handleCompletion: (Result<ASAuthorization, any Error>) async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SignInWithAppleButton(.continue) { request in
                configureRequest(request)
            } onCompletion: { result in
                Task {
                    await handleCompletion(result)
                }
            }
            .signInWithAppleButtonStyle(theme.appleButtonStyle)
            .frame(height: 56)
            .disabled(isSigningIn || isPreviewEnvironment)

            if isPreviewEnvironment {
                Text("Sign in with Apple is unavailable in SwiftUI previews. Run TrustMap in the Simulator or on a device to test authentication.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, WelcomeLayout.horizontalContentPadding)
        .padding(.top, 38)
        .padding(.bottom, 20)
    }
}

private struct WelcomeBackgroundView: View {
    let theme: WelcomeTheme

    var body: some View {
        ZStack {
            theme.baseBackground

            Circle()
                .fill(theme.backgroundGlowTop)
                .frame(width: 320, height: 320)
                .offset(x: 130, y: -220)
                .blur(radius: 90)

            Circle()
                .fill(theme.backgroundGlowBottom)
                .frame(width: 280, height: 280)
                .offset(x: -110, y: 250)
                .blur(radius: 80)

            RoundedRectangle(cornerRadius: 56, style: .continuous)
                .fill(theme.backgroundVeil)
                .frame(width: 420, height: 360)
                .rotationEffect(.degrees(theme.isDark ? -18 : -14))
                .offset(x: 80, y: -30)
                .blur(radius: 12)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

private struct WelcomeTheme {
    let colorScheme: ColorScheme

    var isDark: Bool {
        colorScheme == .dark
    }

    var baseBackground: Color {
        isDark
            ? Color(red: 0.05, green: 0.07, blue: 0.09)
            : Color(red: 0.96, green: 0.97, blue: 0.98)
    }

    var backgroundGlowTop: Color {
        isDark
            ? Color(red: 0.16, green: 0.20, blue: 0.40).opacity(0.34)
            : Color(red: 0.78, green: 0.84, blue: 1.0).opacity(0.9)
    }

    var backgroundGlowBottom: Color {
        isDark
            ? Color(red: 0.16, green: 0.17, blue: 0.28).opacity(0.28)
            : Color(red: 0.89, green: 0.92, blue: 1.0).opacity(0.86)
    }

    var backgroundVeil: Color {
        isDark
            ? Color.white.opacity(0.05)
            : Color.white.opacity(0.34)
    }

    var cardFill: Color {
        isDark
            ? Color(red: 0.09, green: 0.11, blue: 0.15).opacity(0.84)
            : Color.white.opacity(0.78)
    }

    var cardStroke: Color {
        isDark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.07)
    }

    var cardShadow: Color {
        isDark
            ? Color.black.opacity(0.42)
            : Color.black.opacity(0.12)
    }

    var cardShadowRadius: CGFloat {
        isDark ? 24 : 18
    }

    var brandBorder: Color {
        isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)
    }

    var brandShadow: Color {
        Color.black.opacity(isDark ? 0.30 : 0.12)
    }

    var headlineAccent: Color {
        isDark
            ? Color(red: 0.77, green: 0.78, blue: 1.0)
            : Color(red: 0.24, green: 0.28, blue: 0.62)
    }

    var imageStroke: Color {
        isDark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.05)
    }

    var appleButtonStyle: SignInWithAppleButton.Style {
        isDark ? .white : .black
    }
}

#Preview("Light") {
    let container = PreviewAppFactory.makeContainer(session: .signedOut)
    WelcomeView(
        viewModel: WelcomeViewModel(
            sessionStore: container.sessionStore,
            authService: container.authService
        )
    )
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    let container = PreviewAppFactory.makeContainer(session: .signedOut)
    WelcomeView(
        viewModel: WelcomeViewModel(
            sessionStore: container.sessionStore,
            authService: container.authService
        )
    )
    .preferredColorScheme(.dark)
}

#Preview("Small iPhone") {
    let container = PreviewAppFactory.makeContainer(session: .signedOut)
    WelcomeView(
        viewModel: WelcomeViewModel(
            sessionStore: container.sessionStore,
            authService: container.authService
        )
    )
    .preferredColorScheme(.light)
}

#Preview("Large iPhone") {
    let container = PreviewAppFactory.makeContainer(session: .signedOut)
    WelcomeView(
        viewModel: WelcomeViewModel(
            sessionStore: container.sessionStore,
            authService: container.authService
        )
    )
    .preferredColorScheme(.dark)
}
