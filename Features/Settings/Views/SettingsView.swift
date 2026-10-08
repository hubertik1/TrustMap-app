import SwiftUI

struct SettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    private let container: AppContainer
    @StateObject private var viewModel: SettingsViewModel
    @State private var showsDeleteAccountConfirmation = false
    @State private var showsSignOutConfirmation = false

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
        .navigationTitle(L10n.settings)
        .navigationBarTitleDisplayMode(.inline)
        .trustMapPhoneTabBarHidden()
        .task {
            await viewModel.refreshSettingsState()
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await viewModel.refreshSettingsState()
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
            accountActionsSection
        }
    }

    private var accountSection: some View {
        Section(L10n.account) {
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
            }
        }
    }

    private var accountActionsSection: some View {
        Section(L10n.accountManagement) {
            if viewModel.currentUser != nil {
                Button(L10n.signOut, role: .destructive) {
                    showsSignOutConfirmation = true
                }
                .disabled(viewModel.isSigningOut || viewModel.isDeletingAccount)
                .confirmationDialog(L10n.confirmSignOut, isPresented: $showsSignOutConfirmation, titleVisibility: .visible) {
                    Button(L10n.signOut, role: .destructive) {
                        Task { await viewModel.signOut() }
                    }
                    Button(L10n.cancel, role: .cancel) {}
                } message: {
                    Text(L10n.areYouSureYouWantToSignOut)
                }

                Button(role: .destructive) {
                    showsDeleteAccountConfirmation = true
                } label: {
                    if viewModel.isDeletingAccount {
                        HStack {
                            ProgressView()
                            Text(L10n.deletingAccount)
                        }
                    } else {
                        Text(L10n.deleteAccount)
                    }
                }
                .disabled(viewModel.isSigningOut || viewModel.isDeletingAccount)
                .confirmationDialog(L10n.confirmDeleteAccount, isPresented: $showsDeleteAccountConfirmation, titleVisibility: .visible) {
                    Button(L10n.deleteAccount, role: .destructive) {
                        Task { await viewModel.deleteAccount() }
                    }
                    Button(L10n.cancel, role: .cancel) {}
                } message: {
                    Text(L10n.thisPermanentlyRemovesYourProfileReviewsPhotosFriendsAndPrivateCustomPlacesThatNoOneElseUsesT)
                }

                if let accountDeletionErrorMessage = viewModel.accountDeletionErrorMessage {
                    Text(accountDeletionErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var permissionsSection: some View {
        Section(L10n.permissions) {
            Button {
                viewModel.openLocationSettings()
            } label: {
                NavigationValueRow(
                    title: L10n.locationAccess,
                    value: viewModel.locationAccessLabel
                )
            }
            .buttonStyle(.plain)

            Button {
                Task { await viewModel.handleNotificationAccessTapped() }
            } label: {
                NavigationValueRow(
                    title: L10n.notifications,
                    value: viewModel.notificationAccessLabel
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var privacySection: some View {
        Section {
            Picker(L10n.friendsList, selection: privacyBinding(
                get: { viewModel.friendListVisibility },
                set: { viewModel.setFriendListVisibility($0) }
            )) {
                ForEach(VisibilityStatus.friendListPrivacyOptions) { status in
                    Text(status.displayName).tag(status)
                }
            }
            .pickerStyle(.menu)
            .disabled(isPrivacyControlDisabled)

            Picker(L10n.profilePhoto, selection: privacyBinding(
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
                Text(L10n.privacySettingsAreNotAvailableOnThisServerVersion)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let privacyErrorMessage = viewModel.privacyErrorMessage {
                Text(privacyErrorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            NavigationLink {
                BlockedUsersView(repository: container.safetyRepository)
            } label: {
                Text(L10n.blockedUsers)
            }
        } header: {
            Text(L10n.privacy)
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
            Picker(L10n.defaultMapStyle, selection: binding(\.defaultMapStyle)) {
                ForEach(AppMapStylePreference.allCases) { style in
                    Text(style.displayName).tag(style)
                }
            }
            .pickerStyle(.menu)

            Toggle(L10n.centerOnMyLocation, isOn: binding(\.centerOnUserLocationOnLaunch))
        } header: {
            Text(L10n.mapDiscovery)
        }
    }

    private var appearanceSection: some View {
        Section(L10n.appearance) {
            Picker(L10n.theme, selection: binding(\.appearance)) {
                ForEach(AppAppearancePreference.allCases) { preference in
                    Text(preference.displayName).tag(preference)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var aboutSection: some View {
        Section(L10n.about) {
            LabeledContent(L10n.build, value: viewModel.appVersionBuildLabel)

            if let privacyPolicyURL = viewModel.privacyPolicyURL {
                linkRow(title: L10n.privacyPolicy, destination: privacyPolicyURL)
            }

            if let supportURL = viewModel.supportURL {
                linkRow(title: L10n.support, destination: supportURL)
            }

            if let termsOfServiceURL = viewModel.termsOfServiceURL {
                linkRow(title: L10n.termsOfService, destination: termsOfServiceURL)
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
