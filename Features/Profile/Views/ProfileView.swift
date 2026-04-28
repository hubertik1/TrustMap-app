import PhotosUI
import SwiftUI

struct ProfileView: View {
    @ObservedObject private var container: AppContainer
    @ObservedObject private var refreshCenter: AppRefreshCenter
    @StateObject private var viewModel: ProfileViewModel
    @State private var isPresentingEditProfile = false

    init(container: AppContainer) {
        self.container = container
        self.refreshCenter = container.refreshCenter
        _viewModel = StateObject(
            wrappedValue: ProfileViewModel(
                refreshCenter: container.refreshCenter,
                sessionStore: container.sessionStore,
                userRepository: container.userRepository,
                friendRepository: container.friendRepository,
                categoryRepository: container.categoryRepository,
                placeReviewRepository: container.placeReviewRepository,
                dishReviewRepository: container.dishReviewRepository
            )
        )
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                LoadingStateView(title: "Loading profile")
            } else if let errorMessage = viewModel.errorMessage {
                ErrorStateView(message: errorMessage) {
                    Task { await viewModel.load() }
                }
            } else if let user = viewModel.user ?? container.sessionStore.currentUser {
                profileContent(for: user)
            } else {
                EmptyStateView(
                    title: "Profile Unavailable",
                    message: "TrustMap could not load your account data yet. Pull to retry or reopen the app.",
                    systemImage: "person.crop.circle.badge.exclamationmark"
                )
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: refreshCenter.globalRevision) {
            await viewModel.load()
        }
        .sheet(isPresented: $isPresentingEditProfile) {
            NavigationStack {
                ProfileEditorSheet(viewModel: viewModel)
            }
        }
    }

    private func profileContent(for user: User) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                ProfileHeroCard(
                    user: user,
                    friendCount: viewModel.friendsSummary.friendCount,
                    pendingRequestCount: viewModel.friendsSummary.pendingRequestCount,
                    ratedPlacesCount: viewModel.stats.ratedPlacesCount,
                    reviewedDishesCount: viewModel.stats.reviewedDishesCount,
                    onEditProfile: presentProfileEditor
                ) {
                    FriendsView(container: container)
                } placesDestination: {
                    MyPlaceReviewsView(
                        container: container,
                        reviews: viewModel.placeReviews,
                        placeNames: viewModel.placeNames,
                        onDelete: { review in
                            try await viewModel.deletePlaceReview(review)
                        }
                    )
                } dishesDestination: {
                    MyDishReviewsView(
                        container: container,
                        reviews: viewModel.dishReviews,
                        placeNames: viewModel.placeNames,
                        onDelete: { review in
                            try await viewModel.deleteDishReview(review)
                        }
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    ProfileSectionHeader(title: "Your activity")

                    ProfileCardGroup {
                        NavigationLink {
                            MyPlaceReviewsView(
                                container: container,
                                reviews: viewModel.placeReviews,
                                placeNames: viewModel.placeNames,
                                onDelete: { review in
                                    try await viewModel.deletePlaceReview(review)
                                }
                            )
                        } label: {
                            ProfileCardRow(
                                icon: "mappin.and.ellipse",
                                iconColor: .red,
                                title: "Rated Places",
                                value: viewModel.stats.ratedPlacesCount.formatted()
                            )
                        }
                        .buttonStyle(.plain)

                        ProfileCardDivider()

                        NavigationLink {
                            MyDishReviewsView(
                                container: container,
                                reviews: viewModel.dishReviews,
                                placeNames: viewModel.placeNames,
                                onDelete: { review in
                                    try await viewModel.deleteDishReview(review)
                                }
                            )
                        } label: {
                            ProfileCardRow(
                                icon: "fork.knife",
                                iconColor: .orange,
                                title: "Reviewed Dishes",
                                value: viewModel.stats.reviewedDishesCount.formatted()
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    ProfileSectionHeader(title: "Manage")

                    ProfileCardGroup {
                        NavigationLink {
                            CategoriesView(
                                categoryRepository: container.categoryRepository,
                                refreshCenter: container.refreshCenter
                            )
                        } label: {
                            ProfileCardRow(
                                icon: "tag.fill",
                                iconColor: .blue,
                                title: "Categories",
                                value: viewModel.categoryCount.formatted()
                            )
                        }
                        .buttonStyle(.plain)

                        ProfileCardDivider()

                        NavigationLink {
                            SettingsView(container: container)
                        } label: {
                            ProfileCardRow(
                                icon: "gearshape.fill",
                                iconColor: .secondary,
                                title: "Settings"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 132)
        }
        .refreshable {
            await viewModel.load()
        }
    }

    private func presentProfileEditor() {
        viewModel.prepareProfileEditor()
        isPresentingEditProfile = true
    }
}

private struct ProfileSectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
    }
}

private struct ProfileCardGroup<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .padding(.vertical, 4)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.025), radius: 8, x: 0, y: 3)
    }
}

private struct ProfileCardRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    var value: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(iconColor.opacity(0.86))
                .frame(width: 34, height: 34)
                .background(iconColor.opacity(0.075), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityHidden(true)

            Text(title)
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Spacer(minLength: 10)

            if let value {
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color(uiColor: .tertiaryLabel))
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

private struct ProfileCardDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 62)
            .accessibilityHidden(true)
    }
}

private struct ProfileHeroCard<FriendsDestination: View, PlacesDestination: View, DishesDestination: View>: View {
    let user: User
    let friendCount: Int
    let pendingRequestCount: Int
    let ratedPlacesCount: Int
    let reviewedDishesCount: Int
    let onEditProfile: () -> Void
    @ViewBuilder let friendsDestination: () -> FriendsDestination
    @ViewBuilder let placesDestination: () -> PlacesDestination
    @ViewBuilder let dishesDestination: () -> DishesDestination

    private var bioText: String? {
        let trimmedBio = user.bio?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedBio.isEmpty ? nil : trimmedBio
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 15) {
                AvatarView(name: user.displayName, avatarURL: user.avatarURL, size: 86)
                    .overlay {
                        Circle()
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Profile photo")

                VStack(alignment: .leading, spacing: 5) {
                    Text(user.displayName)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)

                    Text("@\(user.handle)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Button(action: onEditProfile) {
                        Text("Edit Profile")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 6)
                            .background(Color.accentColor.opacity(0.07), in: Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(Color.accentColor.opacity(0.18), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 3)
                    .accessibilityLabel("Edit Profile")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let bioText {
                Text(bioText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Add a short bio to help friends recognize you.")
                    .font(.subheadline)
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            ProfileStatsRow(
                friendCount: friendCount,
                pendingRequestCount: pendingRequestCount,
                ratedPlacesCount: ratedPlacesCount,
                reviewedDishesCount: reviewedDishesCount
            ) {
                friendsDestination()
            } placesDestination: {
                placesDestination()
            } dishesDestination: {
                dishesDestination()
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.035), radius: 10, x: 0, y: 4)
    }
}

private struct ProfileStatsRow<FriendsDestination: View, PlacesDestination: View, DishesDestination: View>: View {
    let friendCount: Int
    let pendingRequestCount: Int
    let ratedPlacesCount: Int
    let reviewedDishesCount: Int
    @ViewBuilder let friendsDestination: () -> FriendsDestination
    @ViewBuilder let placesDestination: () -> PlacesDestination
    @ViewBuilder let dishesDestination: () -> DishesDestination

    var body: some View {
        HStack(spacing: 0) {
            NavigationLink {
                friendsDestination()
            } label: {
                ProfileStatColumn(
                    count: friendCount,
                    label: "Friends",
                    pendingRequestCount: pendingRequestCount,
                    accessibilityLabel: friendsAccessibilityLabel
                )
            }
            .buttonStyle(ProfileStatNavigationButtonStyle())

            ProfileStatDivider()

            NavigationLink {
                placesDestination()
            } label: {
                ProfileStatColumn(
                    count: ratedPlacesCount,
                    label: "Places",
                    accessibilityLabel: "\(ratedPlacesCount) rated places"
                )
            }
            .buttonStyle(ProfileStatNavigationButtonStyle())

            ProfileStatDivider()

            NavigationLink {
                dishesDestination()
            } label: {
                ProfileStatColumn(
                    count: reviewedDishesCount,
                    label: "Dishes",
                    accessibilityLabel: "\(reviewedDishesCount) reviewed dishes"
                )
            }
            .buttonStyle(ProfileStatNavigationButtonStyle())
        }
    }

    private var friendsAccessibilityLabel: String {
        if pendingRequestCount == 1 {
            return "\(friendCount) friends, 1 pending request"
        }

        if pendingRequestCount > 1 {
            return "\(friendCount) friends, \(pendingRequestCount) pending requests"
        }

        return "\(friendCount) friends"
    }
}

private struct ProfileStatNavigationButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.045 : 0))
            }
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct ProfileStatColumn: View {
    let count: Int
    let label: String
    var pendingRequestCount = 0
    let accessibilityLabel: String

    private var pendingRequestBadgeText: String {
        pendingRequestCount > 9 ? "9+" : pendingRequestCount.formatted()
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(count.formatted())
                .font(.headline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            HStack(spacing: 5) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                if pendingRequestCount > 0 {
                    Text(pendingRequestBadgeText)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .padding(.horizontal, 5)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(.red, in: Capsule())
                        .fixedSize(horizontal: true, vertical: false)
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 52)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Opens \(label.lowercased())")
        .accessibilityAddTraits(.isButton)
    }
}

private struct ProfileStatDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.06))
            .frame(width: 1, height: 36)
            .accessibilityHidden(true)
    }
}

private struct ProfileEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ProfileViewModel
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isShowingDiscardConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    ProfileEditorSectionHeader(title: "Profile photo")
                    ProfileEditorCard {
                        profilePhotoEditor
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    ProfileEditorSectionHeader(title: "Public profile")
                    ProfileEditorCard {
                        publicProfileForm
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .scrollDismissesKeyboard(.interactively)
        .disabled(viewModel.isSavingProfile)
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: selectedPhotoItem) {
            await prepareSelectedPhoto(from: selectedPhotoItem)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    cancelEditing()
                } label: {
                    ProfileEditorToolbarButtonLabel(title: "Cancel")
                }
                .buttonStyle(.plain)
                .fixedSize(horizontal: true, vertical: false)
                .disabled(viewModel.isSavingProfile)
            }

            ToolbarItem(placement: .confirmationAction) {
                if viewModel.isSavingProfile {
                    ProgressView()
                } else {
                    Button {
                        save()
                    } label: {
                        ProfileEditorToolbarButtonLabel(title: "Save")
                    }
                    .buttonStyle(.plain)
                    .fixedSize(horizontal: true, vertical: false)
                    .foregroundStyle(viewModel.canSaveProfile ? Color.accentColor : Color.secondary)
                    .disabled(!viewModel.canSaveProfile)
                }
            }
        }
        .confirmationDialog(
            "Discard changes?",
            isPresented: $isShowingDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard Changes", role: .destructive) {
                dismiss()
            }

            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("Your profile edits won't be saved.")
        }
        .alert(
            "Unable to Save Profile",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var publicProfileForm: some View {
        let usernameMessage = viewModel.localUsernameValidationMessage ?? viewModel.usernameErrorMessage

        return VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                ProfileEditorFieldLabel("Display name")

                ProfileEditorInputContainer(isInvalid: viewModel.displayNameValidationMessage != nil) {
                    TextField(
                        text: $viewModel.editedDisplayName,
                        prompt: Text("Display name").foregroundStyle(.secondary)
                    ) {
                        EmptyView()
                    }
                    .textFieldStyle(.plain)
                    .font(.body)
                    .lineLimit(1)
                    .textInputAutocapitalization(.words)
                }

                if let displayNameValidationMessage = viewModel.displayNameValidationMessage {
                    Text(displayNameValidationMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                ProfileEditorFieldLabel("Username")

                UniqueUsernameFieldRow(
                    usernameBase: $viewModel.editedHandle,
                    suffix: viewModel.editedHandleSuffix,
                    isInvalid: usernameMessage != nil
                )

                Text("Only the name before the suffix can be changed.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let usernameMessage {
                    Text(usernameMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                ProfileEditorFieldLabel("Bio")

                BioEditorField(
                    text: $viewModel.editedBio,
                    isInvalid: viewModel.bioValidationMessage != nil,
                    characterCount: viewModel.bioCharacterCount,
                    characterLimit: viewModel.bioCharacterLimit
                )

                if let bioValidationMessage = viewModel.bioValidationMessage {
                    Text(bioValidationMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var profilePhotoEditor: some View {
        let hasEditedPhoto = viewModel.selectedAvatarPhoto != nil || viewModel.editedAvatarURL != nil
        let photoButtonTitle = hasEditedPhoto ? "Change Photo" : "Add Photo"

        return VStack(alignment: .center, spacing: 14) {
            avatarPreview

            VStack(spacing: 8) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label(photoButtonTitle, systemImage: "photo")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(photoButtonTitle)

                if hasEditedPhoto {
                    Button("Remove Photo", role: .destructive) {
                        selectedPhotoItem = nil
                        viewModel.removeAvatar()
                    }
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.plain)
                    .accessibilityHint("Removes your profile photo.")
                }
            }

            Text("Your photo appears next to your reviews and activity.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }

    private var avatarPreview: some View {
        Group {
            if let image = viewModel.selectedAvatarPhoto?.previewImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                AvatarView(
                    name: viewModel.editedDisplayName.isEmpty ? "TrustMap Member" : viewModel.editedDisplayName,
                    avatarURL: viewModel.editedAvatarURL,
                    size: 112
                )
            }
        }
        .frame(width: 112, height: 112)
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Profile photo")
    }

    private func cancelEditing() {
        guard !viewModel.isSavingProfile else {
            return
        }

        if viewModel.hasUnsavedProfileChanges {
            isShowingDiscardConfirmation = true
        } else {
            dismiss()
        }
    }

    private func save() {
        guard viewModel.canSaveProfile else {
            return
        }

        Task {
            let didSave = await viewModel.saveProfileChanges()
            if didSave {
                dismiss()
            }
        }
    }

    private func prepareSelectedPhoto(from item: PhotosPickerItem?) async {
        guard let item else {
            return
        }

        do {
            guard let rawData = try await item.loadTransferable(type: Data.self) else {
                throw AppError.validationFailure("Select a supported image before uploading.")
            }

            let preparedPhoto = try await PhotoUploadPreparation.prepareSelectedPhoto(from: rawData)
            viewModel.setSelectedAvatarPhoto(preparedPhoto)
        } catch is CancellationError {
            return
        } catch {
            viewModel.errorMessage = AppError.wrap(error).errorDescription
            selectedPhotoItem = nil
        }
    }
}

private struct ProfileEditorToolbarButtonLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 8)
    }
}

private struct ProfileEditorSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
    }
}

private struct ProfileEditorCard<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }
}

private struct ProfileEditorFieldLabel: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }
}

private struct ProfileEditorInputContainer<Content: View>: View {
    let isInvalid: Bool
    let content: () -> Content

    init(isInvalid: Bool = false, @ViewBuilder content: @escaping () -> Content) {
        self.isInvalid = isInvalid
        self.content = content
    }

    var body: some View {
        content()
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isInvalid ? Color.red.opacity(0.82) : Color.primary.opacity(0.06), lineWidth: 1)
            }
    }
}

private struct BioEditorField: View {
    @Binding var text: String
    let isInvalid: Bool
    let characterCount: Int
    let characterLimit: Int

    private var isOverLimit: Bool {
        characterCount > characterLimit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("Tell friends what kind of places you like...")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $text)
                    .font(.body)
                    .frame(minHeight: 112)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
            }

            HStack {
                Spacer(minLength: 12)

                Text("\(characterCount.formatted())/\(characterLimit.formatted())")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(isOverLimit ? .red : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .accessibilityLabel("Bio character count")
                    .accessibilityValue("\(characterCount) of \(characterLimit)")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isInvalid ? Color.red.opacity(0.82) : Color.primary.opacity(0.06), lineWidth: 1)
        }
    }
}

private struct UniqueUsernameFieldRow: View {
    @Binding var usernameBase: String
    let suffix: String
    let isInvalid: Bool

    private var displayedSuffix: String {
        suffix.isEmpty ? "auto" : suffix
    }

    var body: some View {
        ProfileEditorInputContainer(isInvalid: isInvalid) {
            HStack(spacing: 8) {
                TextField(
                    text: $usernameBase,
                    prompt: Text("username").foregroundStyle(.secondary)
                ) {
                    EmptyView()
                }
                .textFieldStyle(.plain)
                .font(.body)
                .lineLimit(1)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.username)
                .layoutPriority(1)
                .accessibilityLabel("Username")
                .accessibilityHint("Editable part of your unique username.")

                Text(displayedSuffix)
                    .font(suffix.isEmpty ? .caption.weight(.semibold) : .body.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, suffix.isEmpty ? 9 : 10)
                    .padding(.vertical, 5)
                    .background(Color(uiColor: .tertiarySystemFill), in: Capsule())
                    .fixedSize(horizontal: true, vertical: false)
                    .accessibilityElement()
                    .accessibilityLabel("Read-only automatic suffix")
                    .accessibilityValue(suffix.isEmpty ? "Assigned automatically" : suffix)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    NavigationStack {
        ProfileView(container: PreviewAppFactory.makeContainer())
    }
}

private struct CategoriesView: View {
    @StateObject private var viewModel: CategoriesViewModel
    @State private var editorPresentation: CategoryEditorPresentation?
    @State private var categoryPendingDeletion: CustomCategory?

    init(categoryRepository: CategoryRepository, refreshCenter: AppRefreshCenter) {
        _viewModel = StateObject(
            wrappedValue: CategoriesViewModel(
                categoryRepository: categoryRepository,
                refreshCenter: refreshCenter
            )
        )
    }

    var body: some View {
        Group {
            if viewModel.isLoading && !viewModel.hasLoadedCategories {
                LoadingStateView(title: "Loading categories")
            } else if let errorMessage = viewModel.errorMessage,
                      !viewModel.hasLoadedCategories {
                ErrorStateView(message: errorMessage) {
                    Task { await viewModel.load() }
                }
            } else {
                List {
                    Section("Default Categories") {
                        if viewModel.defaultCategories.isEmpty {
                            Text("No default categories are available yet.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(viewModel.defaultCategories) { category in
                                CategoryListRow(
                                    category: category,
                                    subtitle: "Available to every TrustMap user",
                                    badgeText: "Default"
                                ) {
                                    if category.canHide {
                                        Button("Hide") {
                                            Task { await viewModel.hideCategory(category) }
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                        .disabled(viewModel.isSubmitting)
                                    }
                                }
                            }
                        }
                    }

                    Section("My Categories") {
                        if viewModel.myCustomCategories.isEmpty {
                            Text("Create a custom category or adopt one from a friend.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(viewModel.myCustomCategories) { category in
                                CategoryListRow(
                                    category: category,
                                    subtitle: subtitle(forActiveCategory: category),
                                    badgeText: category.isOwnedByCurrentUser ? "Mine" : "Added"
                                ) {
                                    if category.canEdit || category.canDelete {
                                        Menu {
                                            if category.canEdit {
                                                Button("Edit") {
                                                    editorPresentation = .edit(category)
                                                }
                                            }

                                            if category.canDelete {
                                                Button("Delete", role: .destructive) {
                                                    categoryPendingDeletion = category
                                                }
                                            }
                                        } label: {
                                            Image(systemName: "ellipsis.circle")
                                                .font(.title3)
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                    } else if category.canHide {
                                        Button("Hide") {
                                            Task { await viewModel.hideCategory(category) }
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                        .disabled(viewModel.isSubmitting)
                                    }
                                }
                            }
                        }
                    }

                    Section("Categories from Friends") {
                        if viewModel.friendCategories.isEmpty {
                            Text("Friend categories you haven't added yet will show up here.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(viewModel.friendCategories) { category in
                                CategoryListRow(
                                    category: category,
                                    subtitle: subtitle(forFriendCategory: category),
                                    badgeText: "Friend"
                                ) {
                                    if category.canAdopt {
                                        Button("Add") {
                                            Task { await viewModel.adoptCategory(category) }
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .controlSize(.small)
                                        .disabled(viewModel.isSubmitting)
                                    }
                                }
                            }
                        }
                    }

                    Section("Hidden Categories") {
                        if viewModel.hiddenCategoryItems.isEmpty {
                            Text("Categories you hide will appear here so you can restore them later.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(viewModel.hiddenCategoryItems) { category in
                                CategoryListRow(
                                    category: category,
                                    subtitle: subtitle(forHiddenCategory: category),
                                    badgeText: category.isDefault ? "Default" : "Hidden"
                                ) {
                                    if category.canUnhide {
                                        Button("Restore") {
                                            Task { await viewModel.unhideCategory(category) }
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .controlSize(.small)
                                        .disabled(viewModel.isSubmitting)
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable {
                    await viewModel.load()
                }
            }
        }
        .navigationTitle("Categories")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editorPresentation = .create
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task {
            await viewModel.load()
        }
        .sheet(item: $editorPresentation) { presentation in
            NavigationStack {
                CategoryEditorSheet(
                    title: presentation.title,
                    actionTitle: presentation.actionTitle,
                    initialName: presentation.initialName,
                    isSaving: viewModel.isSubmitting
                ) { name in
                    switch presentation.kind {
                    case .create:
                        return await viewModel.createCategory(named: name)
                    case .edit(let category):
                        return await viewModel.updateCategory(category, name: name)
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete category?",
            isPresented: Binding(
                get: { categoryPendingDeletion != nil },
                set: { if !$0 { categoryPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let categoryPendingDeletion {
                Button("Delete Category", role: .destructive) {
                    Task {
                        await viewModel.deleteCategory(categoryPendingDeletion)
                        self.categoryPendingDeletion = nil
                    }
                }
            }

            Button("Cancel", role: .cancel) {
                categoryPendingDeletion = nil
            }
        } message: {
            Text("The category will stop being available to everyone, but existing place and review history will stay intact.")
        }
        .alert(
            "Categories",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private func subtitle(forActiveCategory category: CustomCategory) -> String {
        if category.isOwnedByCurrentUser {
            return "Created by you"
        }

        let ownerName = category.ownerDisplayName ?? "A friend"
        return "Added from \(ownerName)"
    }

    private func subtitle(forFriendCategory category: CustomCategory) -> String {
        let ownerName = category.ownerDisplayName ?? "A friend"
        return "Created by \(ownerName)"
    }

    private func subtitle(forHiddenCategory category: CustomCategory) -> String {
        if category.isDefault {
            return "Hidden only for you. Restore it to make it active and selectable again."
        }

        if category.isOwnedByCurrentUser {
            return "Created by you. Restore it to make it active again."
        }

        let ownerName = category.ownerDisplayName ?? "A friend"
        return "Created by \(ownerName). Restore it to make it active again."
    }
}

@MainActor
private final class CategoriesViewModel: ObservableObject {
    @Published private(set) var myCategories: [CustomCategory] = []
    @Published private(set) var friendCategories: [CustomCategory] = []
    @Published private(set) var hiddenCategories: [CustomCategory] = []
    @Published var isLoading = false
    @Published var isSubmitting = false
    @Published var errorMessage: String?

    private let categoryRepository: CategoryRepository
    private let refreshCenter: AppRefreshCenter

    init(categoryRepository: CategoryRepository, refreshCenter: AppRefreshCenter) {
        self.categoryRepository = categoryRepository
        self.refreshCenter = refreshCenter
    }

    var hasLoadedCategories: Bool {
        !myCategories.isEmpty || !friendCategories.isEmpty || !hiddenCategories.isEmpty
    }

    var defaultCategories: [CustomCategory] {
        myCategories
            .filter(\.isDefault)
            .sorted(by: defaultCategorySort)
    }

    var myCustomCategories: [CustomCategory] {
        myCategories
            .filter { !$0.isDefault }
            .sorted(by: myCategorySort)
    }

    var hiddenCategoryItems: [CustomCategory] {
        hiddenCategories.sorted(by: hiddenCategorySort)
    }

    func load() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        await fetchCategories()
    }

    func createCategory(named name: String) async -> Bool {
        await performMutation {
            _ = try await self.categoryRepository.createCategory(name: name)
        }
    }

    func updateCategory(_ category: CustomCategory, name: String) async -> Bool {
        await performMutation {
            _ = try await self.categoryRepository.updateCategory(id: category.id, name: name)
        }
    }

    func adoptCategory(_ category: CustomCategory) async {
        _ = await performMutation {
            _ = try await self.categoryRepository.adoptCategory(id: category.id)
        }
    }

    func hideCategory(_ category: CustomCategory) async {
        _ = await performMutation {
            _ = try await self.categoryRepository.hideCategory(id: category.id)
        }
    }

    func deleteCategory(_ category: CustomCategory) async {
        _ = await performMutation {
            try await self.categoryRepository.deleteCategory(id: category.id)
        }
    }

    func unhideCategory(_ category: CustomCategory) async {
        _ = await performMutation {
            _ = try await self.categoryRepository.unhideCategory(id: category.id)
        }
    }

    private func fetchCategories() async {
        do {
            async let myCategoriesTask = categoryRepository.fetchMyCategories()
            async let friendCategoriesTask = categoryRepository.fetchFriendCategories()
            async let hiddenCategoriesTask = categoryRepository.fetchHiddenCategories()
            let (myCategories, friendCategories, hiddenCategories) = try await (myCategoriesTask, friendCategoriesTask, hiddenCategoriesTask)
            self.myCategories = myCategories
            self.friendCategories = friendCategories.sorted(by: friendCategorySort)
            self.hiddenCategories = hiddenCategories
        } catch {
            errorMessage = AppError.wrap(error).errorDescription
        }
    }

    private func performMutation(_ action: @escaping () async throws -> Void) async -> Bool {
        guard !isSubmitting else {
            return false
        }

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            try await action()
            refreshCenter.invalidateAll()
            await fetchCategories()
            return true
        } catch {
            errorMessage = AppError.wrap(error).errorDescription
            return false
        }
    }

    private func defaultCategorySort(lhs: CustomCategory, rhs: CustomCategory) -> Bool {
        if lhs.id == TrustMapCategory.restaurantsCategoryID {
            return true
        }

        if rhs.id == TrustMapCategory.restaurantsCategoryID {
            return false
        }

        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }

    private func myCategorySort(lhs: CustomCategory, rhs: CustomCategory) -> Bool {
        if lhs.isOwnedByCurrentUser != rhs.isOwnedByCurrentUser {
            return lhs.isOwnedByCurrentUser && !rhs.isOwnedByCurrentUser
        }

        let nameComparison = lhs.name.localizedStandardCompare(rhs.name)
        if nameComparison != .orderedSame {
            return nameComparison == .orderedAscending
        }

        return lhs.id.uuidString < rhs.id.uuidString
    }

    private func friendCategorySort(lhs: CustomCategory, rhs: CustomCategory) -> Bool {
        let nameComparison = lhs.name.localizedStandardCompare(rhs.name)
        if nameComparison != .orderedSame {
            return nameComparison == .orderedAscending
        }

        return (lhs.ownerDisplayName ?? "").localizedStandardCompare(rhs.ownerDisplayName ?? "") == .orderedAscending
    }

    private func hiddenCategorySort(lhs: CustomCategory, rhs: CustomCategory) -> Bool {
        if lhs.isDefault != rhs.isDefault {
            return lhs.isDefault && !rhs.isDefault
        }

        if lhs.id == TrustMapCategory.restaurantsCategoryID {
            return true
        }

        if rhs.id == TrustMapCategory.restaurantsCategoryID {
            return false
        }

        let nameComparison = lhs.name.localizedStandardCompare(rhs.name)
        if nameComparison != .orderedSame {
            return nameComparison == .orderedAscending
        }

        return lhs.id.uuidString < rhs.id.uuidString
    }
}

private struct CategoryEditorPresentation: Identifiable {
    enum Kind {
        case create
        case edit(CustomCategory)
    }

    let kind: Kind

    var id: String {
        switch kind {
        case .create:
            return "create"
        case .edit(let category):
            return category.id.uuidString
        }
    }

    var title: String {
        switch kind {
        case .create:
            return "New Category"
        case .edit:
            return "Edit Category"
        }
    }

    var actionTitle: String {
        switch kind {
        case .create:
            return "Create"
        case .edit:
            return "Save"
        }
    }

    var initialName: String {
        switch kind {
        case .create:
            return ""
        case .edit(let category):
            return category.name
        }
    }

    static var create: Self {
        Self(kind: .create)
    }

    static func edit(_ category: CustomCategory) -> Self {
        Self(kind: .edit(category))
    }
}

private struct CategoryEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String

    let title: String
    let actionTitle: String
    let isSaving: Bool
    let onSave: @MainActor (String) async -> Bool

    init(
        title: String,
        actionTitle: String,
        initialName: String,
        isSaving: Bool,
        onSave: @escaping @MainActor (String) async -> Bool
    ) {
        self.title = title
        self.actionTitle = actionTitle
        self.isSaving = isSaving
        self.onSave = onSave
        _name = State(initialValue: initialName)
    }

    var body: some View {
        Form {
            Section("Category") {
                TextField("Name", text: $name)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
            }

            Section {
                Text("Custom categories are shared objects. Friends can discover and adopt them without creating copies.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .disabled(isSaving)
            }

            ToolbarItem(placement: .confirmationAction) {
                if isSaving {
                    ProgressView()
                } else {
                    Button(actionTitle) {
                        Task {
                            if await onSave(name) {
                                dismiss()
                            }
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct CategoryListRow<TrailingContent: View>: View {
    let category: CustomCategory
    let subtitle: String
    let badgeText: String?
    @ViewBuilder let trailingContent: () -> TrailingContent

    init(
        category: CustomCategory,
        subtitle: String,
        badgeText: String? = nil,
        @ViewBuilder trailingContent: @escaping () -> TrailingContent = { EmptyView() }
    ) {
        self.category = category
        self.subtitle = subtitle
        self.badgeText = badgeText
        self.trailingContent = trailingContent
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(category.name)
                        .font(.body.weight(.semibold))

                    if let badgeText {
                        CategoryBadge(text: badgeText)
                    }
                }

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            trailingContent()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CategoryBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(.secondarySystemBackground), in: Capsule())
    }
}
