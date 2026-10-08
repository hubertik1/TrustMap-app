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
        if TrustMapPlatform.isMacCatalyst {
            macBody
        } else {
            phoneBody
        }
    }

    private var phoneBody: some View {
        NavigationStack {
            GeometryReader { geometry in
                let compact = geometry.size.height < 700
                VStack(spacing: compact ? 12 : 18) {
                    WelcomeBrandHeader(theme: theme, compact: compact)

                    heroSection(compact: compact)

                    GeometryReader { previewGeometry in
                        let artworkSize = max(0, min(
                            previewGeometry.size.width,
                            previewGeometry.size.height,
                            420
                        ))
                        WelcomePreviewCard(theme: theme)
                            .environment(\.dynamicTypeSize, .medium)
                            .frame(width: 340, height: 340)
                            .scaleEffect(artworkSize / 340)
                            .frame(width: previewGeometry.size.width, height: previewGeometry.size.height)
                    }
                    .frame(minHeight: 0)

                    WelcomeCTASection(
                        theme: theme,
                        isSigningIn: viewModel.isSigningIn,
                        isPreviewEnvironment: AppConfiguration.isRunningPreviews,
                        horizontalPadding: 0,
                        topPadding: 0,
                        bottomPadding: 4,
                        configureRequest: viewModel.configure(_:),
                        handleCompletion: viewModel.handleSignInCompletion(_:)
                    )
                }
                .padding(.horizontal, WelcomeLayout.horizontalContentPadding)
                .padding(.top, compact ? 8 : 16)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background {
                WelcomeBackgroundView(theme: theme)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var macBody: some View {
        NavigationStack {
            ZStack {
                WelcomeBackgroundView(theme: theme)

                GeometryReader { geometry in
                    ScrollView {
                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .center, spacing: 64) {
                                macHeroColumn
                                    .frame(maxWidth: 480, alignment: .leading)

                                WelcomePreviewCard(theme: theme)
                                    .frame(maxWidth: 540)
                            }

                            VStack(alignment: .leading, spacing: 36) {
                                macHeroColumn
                                WelcomePreviewCard(theme: theme)
                            }
                        }
                        .frame(maxWidth: 1180)
                        .frame(minHeight: geometry.size.height, alignment: .center)
                        .padding(.horizontal, 56)
                        .padding(.vertical, 44)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func heroSection(compact: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 14) {
            Text(L10n.keepThePlacesYourPeopleTrustAllInOneMap)
                .foregroundStyle(.primary)
                .font(.system(size: compact ? 23 : 27, weight: .bold, design: .rounded))
                .tracking(-0.15)
                .lineSpacing(compact ? 1 : 3)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(L10n.keepThePlacesYourPeopleTrustAllInOneMap)

            Text(L10n.saveFavoriteSpotsCompareNotesAndRevisitTrustedPicksFromYourFriends)
                .font(.system(size: compact ? 14 : 16))
                .foregroundStyle(.secondary)
                .lineSpacing(compact ? 1 : 3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var macHeroColumn: some View {
        VStack(alignment: .leading, spacing: 30) {
            WelcomeBrandHeader(theme: theme)

            heroSection()
                .frame(maxWidth: 460, alignment: .leading)

            WelcomeCTASection(
                theme: theme,
                isSigningIn: viewModel.isSigningIn,
                isPreviewEnvironment: AppConfiguration.isRunningPreviews,
                horizontalPadding: 0,
                configureRequest: viewModel.configure(_:),
                handleCompletion: viewModel.handleSignInCompletion(_:)
            )
            .frame(maxWidth: 420, alignment: .leading)
        }
    }
}

private struct WelcomeBrandHeader: View {
    let theme: WelcomeTheme
    var compact = false

    var body: some View {
        HStack(spacing: 14) {
            Image("TrustMapBrandMark")
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .frame(width: compact ? 50 : 62, height: compact ? 50 : 62)
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

                Text(L10n.privateRecommendationsFromTrustedFriends)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
    }
} 

private struct WelcomePreviewCard: View {
    let theme: WelcomeTheme

    var body: some View {
        WelcomeMapPreview()
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(theme.cardStroke, lineWidth: 3)
            }
            .shadow(color: theme.cardShadow, radius: theme.cardShadowRadius, y: 16)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L10n.welcomePreviewDescription)
    }
}

private struct WelcomeCTASection: View {
    let theme: WelcomeTheme
    let isSigningIn: Bool
    let isPreviewEnvironment: Bool
    var horizontalPadding = WelcomeLayout.horizontalContentPadding
    var topPadding: CGFloat = 38
    var bottomPadding: CGFloat = 20
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
            // Recreate the native button when the scheme changes so its style refreshes.
            .id(theme.colorScheme)
            .frame(height: 56)
            .disabled(isSigningIn || isPreviewEnvironment)

            HStack(spacing: 24) {
                if let privacyPolicyURL = AppConfiguration.privacyPolicyURL {
                    Link(L10n.privacyPolicy, destination: privacyPolicyURL)
                        .frame(minHeight: 44)
                }
                if let supportURL = AppConfiguration.supportURL {
                    Link(L10n.support, destination: supportURL)
                        .frame(minHeight: 44)
                }
            }
            .font(.footnote)
            .tint(.secondary)
            .frame(maxWidth: .infinity)

            if isSigningIn {
                ProgressView(L10n.signingIn)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityLabel(L10n.signingInWaitingForTheServer)
            }

            if isPreviewEnvironment {
                Text(L10n.signInWithAppleIsUnavailableInSwiftuiPreviewsRunTrustmapInTheSimulatorOrOnADeviceToTestAut)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, topPadding)
        .padding(.bottom, bottomPadding)
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

    var cardStroke: Color {
        // TrustMap website brand purple (#352A85), lifted for dark backgrounds.
        isDark
            ? Color(red: 0.56, green: 0.50, blue: 0.88)
            : Color(red: 53 / 255, green: 42 / 255, blue: 133 / 255)
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
