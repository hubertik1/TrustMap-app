import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel: SettingsViewModel

    init(container: AppContainer) {
        _viewModel = StateObject(
            wrappedValue: SettingsViewModel(
                sessionStore: container.sessionStore,
                preferencesStore: container.preferencesStore,
                refreshCenter: container.refreshCenter,
                userRepository: container.userRepository,
                userLocationService: container.userLocationService
            )
        )
    }

    var body: some View {
        Form {
            accountSection
            reviewDefaultsSection
            privacySection
            mapAndDiscoverySection
            appearanceSection
            aboutSection
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.refreshLocationAuthorizationStatus()
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            viewModel.refreshLocationAuthorizationStatus()
        }
    }

    private var accountSection: some View {
        Section("Account") {
            AccountSummaryRow(
                displayName: viewModel.currentUser?.displayName ?? "TrustMap Member",
                avatarURL: viewModel.currentUser?.avatarURL,
                handle: "@\(viewModel.currentUser?.handle ?? "account")"
            )

            LabeledContent("Sign in", value: "Apple")

            Button("Sign Out", role: .destructive) {
                Task { await viewModel.signOut() }
            }
            .disabled(viewModel.isSigningOut)
        }
    }

    private var reviewDefaultsSection: some View {
        Section {
            Picker("New place reviews", selection: binding(\.defaultPlaceReviewVisibility)) {
                ForEach(VisibilityStatus.allCases) { status in
                    Text(status.displayName).tag(status)
                }
            }
            .pickerStyle(.menu)

            Picker("New dish reviews", selection: binding(\.defaultDishReviewVisibility)) {
                ForEach(VisibilityStatus.allCases) { status in
                    Text(status.displayName).tag(status)
                }
            }
            .pickerStyle(.menu)
        } header: {
            Text("Review Defaults")
        } footer: {
            Text("These defaults apply only to new reviews. Existing reviews keep their current visibility.")
        }
    }

    private var privacySection: some View {
        Section {
            Toggle("Show my friends to others", isOn: friendsVisibilityBinding)
                .disabled(viewModel.currentUser == nil || viewModel.isUpdatingFriendsPrivacy)

            if viewModel.isUpdatingFriendsPrivacy {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Updating privacy...")
                        .foregroundStyle(.secondary)
                }
                .font(.footnote)
            }
        } header: {
            Text("Privacy")
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                Text("When this is off, other users can see your profile and visible reviews, but not your friend list.")

                if let privacyErrorMessage = viewModel.privacyErrorMessage {
                    Text(privacyErrorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var mapAndDiscoverySection: some View {
        Section {
            LabeledContent("Location access", value: viewModel.locationAccessLabel)

            Picker("Default map style", selection: binding(\.defaultMapStyle)) {
                ForEach(AppMapStylePreference.allCases) { style in
                    Text(style.displayName).tag(style)
                }
            }
            .pickerStyle(.menu)

            Toggle("Center on my location", isOn: binding(\.centerOnUserLocationOnLaunch))

            if viewModel.showsOpenSystemSettings {
                Button("Open iPhone Settings") {
                    openAppSettings()
                }
            }
        } header: {
            Text("Map & Discovery")
        } footer: {
            Text("These settings are stored only on this device.")
        }
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Theme", selection: binding(\.appearance)) {
                ForEach(AppAppearancePreference.allCases) { preference in
                    Text(preference.displayName).tag(preference)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var aboutSection: some View {
        Section("About") {
            if let privacyPolicyURL = viewModel.privacyPolicyURL {
                linkRow(title: "Privacy Policy", destination: privacyPolicyURL)
            }

            if let termsOfServiceURL = viewModel.termsOfServiceURL {
                linkRow(title: "Terms of Service", destination: termsOfServiceURL)
            }

            LabeledContent("Build", value: viewModel.buildSummary)
        }
    }

    private func binding<Value>(_ keyPath: ReferenceWritableKeyPath<SettingsViewModel, Value>) -> Binding<Value> {
        Binding(
            get: { viewModel[keyPath: keyPath] },
            set: { viewModel[keyPath: keyPath] = $0 }
        )
    }

    private var friendsVisibilityBinding: Binding<Bool> {
        Binding(
            get: { viewModel.friendsVisibleToOthers },
            set: { newValue in
                Task { await viewModel.setFriendsVisibleToOthers(newValue) }
            }
        )
    }

    private func openAppSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            return
        }

        openURL(settingsURL)
    }

    private func linkRow(title: String, destination: URL) -> some View {
        Link(destination: destination) {
            HStack {
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct AccountSummaryRow: View {
    let displayName: String
    let avatarURL: URL?
    let handle: String

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(name: displayName, avatarURL: avatarURL, size: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.body.weight(.semibold))

                Text(handle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        SettingsView(container: PreviewAppFactory.makeContainer())
    }
}
