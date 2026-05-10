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
                userLocationService: container.userLocationService,
                userNotificationPermissionService: container.userNotificationPermissionService
            )
        )
    }

    var body: some View {
        Form {
            accountSection
            privacySection
            mapAndDiscoverySection
            appearanceSection
            aboutSection
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.refreshAuthorizationStatuses()
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await viewModel.refreshAuthorizationStatuses()
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

    private var privacySection: some View {
        Section {
            Picker("Reviews", selection: privacyBinding(
                get: { viewModel.reviewVisibility },
                set: { viewModel.setReviewVisibility($0) }
            )) {
                ForEach(VisibilityStatus.reviewPrivacyOptions) { status in
                    Text(status.displayName).tag(status)
                }
            }
            .pickerStyle(.menu)
            .disabled(isPrivacyControlDisabled)

            Picker("Friends list", selection: privacyBinding(
                get: { viewModel.friendListVisibility },
                set: { viewModel.setFriendListVisibility($0) }
            )) {
                ForEach(VisibilityStatus.friendListPrivacyOptions) { status in
                    Text(status.displayName).tag(status)
                }
            }
            .pickerStyle(.menu)
            .disabled(isPrivacyControlDisabled)

            Picker("Profile", selection: privacyBinding(
                get: { viewModel.profileVisibility },
                set: { viewModel.setProfileVisibility($0) }
            )) {
                ForEach(VisibilityStatus.profilePrivacyOptions) { status in
                    Text(status.displayName).tag(status)
                }
            }
            .pickerStyle(.menu)
            .disabled(isPrivacyControlDisabled)

            Picker("Profile photo", selection: privacyBinding(
                get: { viewModel.profilePictureVisibility },
                set: { viewModel.setProfilePictureVisibility($0) }
            )) {
                ForEach(VisibilityStatus.profilePicturePrivacyOptions) { status in
                    Text(status.displayName).tag(status)
                }
            }
            .pickerStyle(.menu)
            .disabled(isPrivacyControlDisabled)

            if viewModel.currentUser != nil && !viewModel.supportsPrivacySettings {
                Text("Privacy settings are not available on this server version.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let privacyErrorMessage = viewModel.privacyErrorMessage {
                Text(privacyErrorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("Privacy")
        }
    }

    private var isPrivacyControlDisabled: Bool {
        viewModel.currentUser == nil || !viewModel.supportsPrivacySettings || viewModel.isUpdatingPrivacy
    }

    private func privacyBinding(
        get: @escaping () -> VisibilityStatus,
        set: @escaping (VisibilityStatus) -> Void
    ) -> Binding<VisibilityStatus> {
        Binding {
            get()
        } set: { newValue in
            set(newValue)
        }
    }

    private var mapAndDiscoverySection: some View {
        Section {
            LabeledContent("Location access", value: viewModel.locationAccessLabel)
            LabeledContent("Notifications", value: viewModel.notificationAccessLabel)

            notificationSettingsButton

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

    @ViewBuilder
    private var notificationSettingsButton: some View {
        switch viewModel.notificationAuthorizationStatus {
        case .notDetermined:
            Button("Enable Notifications") {
                Task { await viewModel.requestNotificationAuthorization() }
            }

        case .denied:
            Button("Open Notification Settings") {
                viewModel.openNotificationSettings()
            }

        case .authorized, .provisional, .ephemeral:
            Button("Manage Notifications") {
                viewModel.openNotificationSettings()
            }

        @unknown default:
            EmptyView()
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
