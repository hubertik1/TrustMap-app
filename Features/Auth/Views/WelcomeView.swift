import AuthenticationServices
import SwiftUI

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

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        WelcomeBrandHeader(theme: theme)
                        heroSection
                        WelcomePreviewCard(theme: theme)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 28)
                    .padding(.bottom, 36)
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

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            (
                Text("Keep the places ")
                    .foregroundStyle(.primary) +
                Text("your people trust")
                    .foregroundStyle(theme.headlineAccent) +
                Text("\nall in one map.")
                    .foregroundStyle(.primary)
            )
            .font(.system(size: 33, weight: .bold, design: .rounded))
            .tracking(-0.3)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel("Keep the places your people trust all in one map.")

            Text("Save favorite spots, compare notes, and revisit trusted picks from your accepted friends without turning it into a public feed.")
                .font(.system(size: 17))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct WelcomeBrandHeader: View {
    let theme: WelcomeTheme

    var body: some View {
        HStack(spacing: 16) {
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

            VStack(alignment: .leading, spacing: 2) {
                Text("TrustMap")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text("Private recommendations from people you trust")
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
        VStack(alignment: .leading, spacing: 14) {
            Image("WelcomeScreenMap")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(maxWidth: 316)
                .frame(height: 420)
                .background(theme.previewImageBackground)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(theme.imageStroke, lineWidth: 1)
                }
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 6) {
                Text("See trusted spots, ratings, and notes at a glance.")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
        }
        .padding(18)
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
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 14)
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

    var previewImageBackground: Color {
        isDark
            ? Color(red: 0.08, green: 0.09, blue: 0.13)
            : Color.white
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
