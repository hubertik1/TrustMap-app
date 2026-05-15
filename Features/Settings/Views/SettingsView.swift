import SwiftUI

struct SettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    private let container: AppContainer
    @StateObject private var viewModel: SettingsViewModel
    @State private var showsDeleteAccountConfirmation = false

    init(container: AppContainer) {
        self.container = container
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
        settingsContent
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .trustMapPhoneTabBarHidden()
        .task {
            await viewModel.refreshSettingsState()
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await viewModel.refreshSettingsState()
        }
        .alert("Delete Account?", isPresented: $showsDeleteAccountConfirmation) {
            Button("Delete Account", role: .destructive) {
                Task { await viewModel.deleteAccount() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes your profile, reviews, photos, friends, and private custom places that no one else uses. This can’t be undone.")
        }
    }

    @ViewBuilder
    private var settingsContent: some View {
        if TrustMapPlatform.isMacCatalyst {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                settingsForm
                    .scrollContentBackground(.hidden)
                    .frame(maxWidth: TrustMapLayout.settingsMaxWidth)
            }
        } else {
            settingsForm
        }
    }

    private var settingsForm: some View {
        Form {
            accountSection
            permissionsSection
            privacySection
            mapAndDiscoverySection
            appearanceSection
            aboutSection
        }
    }

    private var accountSection: some View {
        Section("Account") {
            if viewModel.currentUser != nil {
                NavigationLink {
                    ProfileView(container: container)
                } label: {
                    AccountSummaryRow(
                        displayName: viewModel.accountDisplayName,
                        avatarURL: viewModel.accountAvatarURL,
                        handle: viewModel.accountHandleLabel
                    )
                }
                .alignmentGuide(.listRowSeparatorLeading) { dimensions in
                    dimensions[.leading]
                }

                LabeledContent("Sign-in method", value: viewModel.signInMethodLabel)

                Button("Sign Out", role: .destructive) {
                    Task { await viewModel.signOut() }
                }
                .disabled(viewModel.isSigningOut || viewModel.isDeletingAccount)

                Button(role: .destructive) {
                    showsDeleteAccountConfirmation = true
                } label: {
                    if viewModel.isDeletingAccount {
                        HStack {
                            ProgressView()
                            Text("Deleting Account")
                        }
                    } else {
                        Text("Delete Account")
                    }
                }
                .disabled(viewModel.isSigningOut || viewModel.isDeletingAccount)

                if let accountDeletionErrorMessage = viewModel.accountDeletionErrorMessage {
                    Text(accountDeletionErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            } else {
                LabeledContent("Sign in", value: viewModel.signInMethodLabel)
            }
        }
    }

    private var permissionsSection: some View {
        Section("Permissions") {
            Button {
                viewModel.openLocationSettings()
            } label: {
                NavigationValueRow(
                    title: "Location access",
                    value: viewModel.locationAccessLabel
                )
            }
            .buttonStyle(.plain)

            Button {
                Task { await viewModel.handleNotificationAccessTapped() }
            } label: {
                NavigationValueRow(
                    title: "Notifications",
                    value: viewModel.notificationAccessLabel
                )
            }
            .buttonStyle(.plain)
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
            Picker("Default map style", selection: binding(\.defaultMapStyle)) {
                ForEach(AppMapStylePreference.allCases) { style in
                    Text(style.displayName).tag(style)
                }
            }
            .pickerStyle(.menu)

            Toggle("Center on my location", isOn: binding(\.centerOnUserLocationOnLaunch))
        } header: {
            Text("Map & Discovery")
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
            LabeledContent("Build", value: viewModel.appVersionBuildLabel)

            if let privacyPolicyURL = viewModel.privacyPolicyURL {
                linkRow(title: "Privacy Policy", destination: privacyPolicyURL)
            }

            if let termsOfServiceURL = viewModel.termsOfServiceURL {
                linkRow(title: "Terms of Service", destination: termsOfServiceURL)
            }
        }
    }

    private func binding<Value>(_ keyPath: ReferenceWritableKeyPath<SettingsViewModel, Value>) -> Binding<Value> {
        Binding(
            get: { viewModel[keyPath: keyPath] },
            set: { viewModel[keyPath: keyPath] = $0 }
        )
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

private struct NavigationValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .foregroundStyle(.primary)

            Spacer(minLength: 12)

            Text(value)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
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
