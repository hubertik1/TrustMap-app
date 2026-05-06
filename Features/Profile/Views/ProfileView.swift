import PhotosUI
import SwiftUI
import UIKit

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
            if viewModel.isLoading && displayUser == nil {
                LoadingStateView(title: "Loading profile")
            } else if displayUser == nil {
                ProductEmptyStateView(
                    title: "Profile unavailable",
                    message: "We couldn't load your account data.",
                    systemImage: "person.crop.circle.badge.exclamationmark",
                    primaryActionTitle: "Try Again",
                    onPrimaryAction: {
                        Task { await viewModel.load() }
                    }
                )
            } else if let user = displayUser {
                profileContent(for: user)
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

    private var displayUser: User? {
        viewModel.user ?? container.sessionStore.currentUser
    }

    private var refreshErrorBanner: some View {
        Group {
            if let errorMessage = viewModel.errorMessage {
                InlineErrorBanner(title: "Couldn't refresh profile", message: errorMessage) {
                    Task { await viewModel.load() }
                }
            }
        }
    }

    private func profileContent(for user: User) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                refreshErrorBanner

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
                    ProfileSectionHeader(title: "Network")

                    ProfileCardGroup {
                        NavigationLink {
                            FriendsView(container: container)
                        } label: {
                            ProfileCardRow(
                                icon: "person.2.fill",
                                iconColor: .cyan,
                                title: "Friends",
                                subtitle: viewModel.friendsSummary.secondaryText,
                                value: viewModel.friendsSummary.friendCount.formatted()
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(friendsRowAccessibilityLabel)
                    }
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

    private var friendsRowAccessibilityLabel: String {
        "Friends, \(viewModel.friendsSummary.friendCount.formatted()), \(viewModel.friendsSummary.secondaryText)"
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
    var subtitle: String?
    var value: String?

    init(icon: String, iconColor: Color, title: String, subtitle: String? = nil, value: String? = nil) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.value = value
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(iconColor.opacity(0.86))
                .frame(width: 34, height: 34)
                .background(iconColor.opacity(0.075), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.86)
                }
            }

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

private struct ProfileEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ProfileViewModel
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var pendingAvatarCrop: PendingAvatarCrop?
    @State private var isPreparingCroppedAvatar = false
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
            await loadPendingAvatarCrop(from: selectedPhotoItem)
        }
        .fullScreenCover(item: $pendingAvatarCrop, onDismiss: avatarCropperDidDismiss) { pendingCrop in
            ProfilePhotoCropperView(
                image: pendingCrop.image,
                isPreparingPhoto: isPreparingCroppedAvatar,
                errorMessage: viewModel.errorMessage,
                onCancel: cancelAvatarCropping,
                onUsePhoto: prepareCroppedAvatarPhoto,
                onCropError: showAvatarCropPreparationError,
                onDismissError: { viewModel.errorMessage = nil }
            )
            .interactiveDismissDisabled(isPreparingCroppedAvatar)
            .id(pendingCrop.id)
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
                get: { viewModel.errorMessage != nil && pendingAvatarCrop == nil },
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
                        pendingAvatarCrop = nil
                        isPreparingCroppedAvatar = false
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

    private func loadPendingAvatarCrop(from item: PhotosPickerItem?) async {
        guard let item else {
            return
        }

        viewModel.errorMessage = nil

        do {
            guard let rawData = try await item.loadTransferable(type: Data.self) else {
                throw AppError.validationFailure("Couldn't load the selected photo. Try another image.")
            }

            guard let image = ProfilePhotoCropperImageLoader.image(from: rawData) else {
                throw AppError.validationFailure("Couldn't load the selected photo. Try another image.")
            }

            pendingAvatarCrop = PendingAvatarCrop(image: image)
        } catch is CancellationError {
            return
        } catch {
            viewModel.errorMessage = "Couldn't load the selected photo. Try another image."
            selectedPhotoItem = nil
            pendingAvatarCrop = nil
        }
    }

    private func prepareCroppedAvatarPhoto(_ croppedImage: UIImage) {
        guard !isPreparingCroppedAvatar else {
            return
        }

        guard let croppedData = croppedImage.jpegData(compressionQuality: 0.9) else {
            showAvatarCropPreparationError()
            return
        }

        isPreparingCroppedAvatar = true
        viewModel.errorMessage = nil

        Task {
            do {
                let preparedPhoto = try await PhotoUploadPreparation.prepareSelectedPhoto(from: croppedData)
                viewModel.setSelectedAvatarPhoto(preparedPhoto)
                finishAvatarCropping()
            } catch is CancellationError {
                isPreparingCroppedAvatar = false
            } catch {
                isPreparingCroppedAvatar = false
                showAvatarCropPreparationError()
            }
        }
    }

    private func cancelAvatarCropping() {
        guard !isPreparingCroppedAvatar else {
            return
        }

        pendingAvatarCrop = nil
        selectedPhotoItem = nil
        viewModel.errorMessage = nil
    }

    private func avatarCropperDidDismiss() {
        guard !isPreparingCroppedAvatar else {
            return
        }

        selectedPhotoItem = nil
        viewModel.errorMessage = nil
    }

    private func finishAvatarCropping() {
        isPreparingCroppedAvatar = false
        pendingAvatarCrop = nil
        selectedPhotoItem = nil
        viewModel.errorMessage = nil
    }

    private func showAvatarCropPreparationError() {
        viewModel.errorMessage = "Couldn't prepare photo. Try another image."
    }
}

private struct PendingAvatarCrop: Identifiable {
    let id = UUID()
    let image: UIImage
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
                categoriesContent
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Categories")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.clearError()
                    editorPresentation = .create
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("New Category")
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
                    helperText: presentation.helperText,
                    initialName: presentation.initialName,
                    isSaving: viewModel.isSubmitting,
                    errorMessage: viewModel.errorMessage
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
            Text("This category will stop being available to you and your friends. Existing reviews will keep their history.")
        }
    }

    private var categoriesContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                if let errorMessage = viewModel.errorMessage {
                    InlineErrorBanner(title: "Couldn't update categories", message: errorMessage) {
                        Task { await viewModel.load() }
                    }
                }

                CategorySection(
                    title: "Default Categories",
                    categories: viewModel.defaultCategories,
                    emptyMessage: "No default categories are available yet."
                ) { category in
                    CategoryRow(
                        category: category
                    ) {
                        if category.canHide {
                            CategoryActionButton(
                                title: "Hide",
                                categoryName: category.name,
                                style: .secondary,
                                isLoading: viewModel.submittingCategoryID == category.id,
                                isDisabled: viewModel.isSubmitting
                            ) {
                                Task { await viewModel.hideCategory(category) }
                            }
                        }
                    }
                }

                CategorySection(
                    title: "My Categories",
                    categories: viewModel.ownCustomCategories,
                    emptyMessage: "Create your own categories to organize places your way."
                ) { category in
                    CategoryRow(
                        category: category,
                        subtitle: "Created by you"
                    ) {
                        if category.canEdit || category.canDelete {
                            ownCategoryMenu(for: category)
                        }
                    }
                }

                CategorySection(
                    title: "Added from Friends",
                    categories: viewModel.addedFriendCategories,
                    emptyMessage: "Categories you add from friends will appear here."
                ) { category in
                    CategoryRow(
                        category: category,
                        subtitle: addedFriendSubtitle(for: category)
                    ) {
                        if category.canHide {
                            CategoryActionButton(
                                title: "Remove",
                                categoryName: category.name,
                                style: .secondary,
                                isLoading: viewModel.submittingCategoryID == category.id,
                                isDisabled: viewModel.isSubmitting
                            ) {
                                Task { await viewModel.hideCategory(category) }
                            }
                        }
                    }
                }

                CategorySection(
                    title: "Categories from Friends",
                    categories: viewModel.availableFriendCategories,
                    emptyMessage: "Friend categories you haven't added yet will show up here."
                ) { category in
                    CategoryRow(
                        category: category,
                        subtitle: availableFriendSubtitle(for: category)
                    ) {
                        if category.canAdopt {
                            CategoryActionButton(
                                title: "Add",
                                categoryName: category.name,
                                style: .primary,
                                isLoading: viewModel.submittingCategoryID == category.id,
                                isDisabled: viewModel.isSubmitting
                            ) {
                                Task { await viewModel.adoptCategory(category) }
                            }
                        }
                    }
                }

                CategorySection(
                    title: "Hidden Default Categories",
                    categories: viewModel.hiddenDefaultCategories,
                    emptyMessage: "Default categories you hide will appear here so you can restore them later."
                ) { category in
                    CategoryRow(
                        category: category,
                        subtitle: "Hidden only for you"
                    ) {
                        if category.canUnhide {
                            CategoryActionButton(
                                title: "Show",
                                categoryName: category.name,
                                style: .primary,
                                isLoading: viewModel.submittingCategoryID == category.id,
                                isDisabled: viewModel.isSubmitting
                            ) {
                                Task { await viewModel.unhideCategory(category) }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 132)
        }
        .refreshable {
            guard !viewModel.isSubmitting else {
                return
            }

            await viewModel.load()
        }
    }

    private func ownCategoryMenu(for category: CustomCategory) -> some View {
        Menu {
            if category.canEdit {
                Button {
                    viewModel.clearError()
                    editorPresentation = .edit(category)
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .accessibilityLabel("Edit \(category.name)")
            }

            if category.canDelete {
                Button(role: .destructive) {
                    categoryPendingDeletion = category
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .accessibilityLabel("Delete \(category.name)")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isSubmitting)
        .accessibilityLabel("Category actions for \(category.name)")
    }

    private func addedFriendSubtitle(for category: CustomCategory) -> String {
        if let ownerName = friendOwnerName(for: category) {
            return "Added from \(ownerName)"
        }

        return "Added from a friend"
    }

    private func availableFriendSubtitle(for category: CustomCategory) -> String {
        if let ownerName = friendOwnerName(for: category) {
            return "Created by \(ownerName)"
        }

        return "Created by a friend"
    }

    private func friendOwnerName(for category: CustomCategory) -> String? {
        let ownerName = category.ownerDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return ownerName.isEmpty ? nil : ownerName
    }
}

@MainActor
private final class CategoriesViewModel: ObservableObject {
    @Published private(set) var myCategories: [CustomCategory] = []
    @Published private(set) var friendCategories: [CustomCategory] = []
    @Published private(set) var hiddenCategories: [CustomCategory] = []
    @Published private(set) var hasLoadedCategories = false
    @Published private(set) var isLoading = false
    @Published private(set) var isSubmitting = false
    @Published private(set) var submittingCategoryID: UUID?
    @Published var errorMessage: String?

    private let categoryRepository: CategoryRepository
    private let refreshCenter: AppRefreshCenter

    init(categoryRepository: CategoryRepository, refreshCenter: AppRefreshCenter) {
        self.categoryRepository = categoryRepository
        self.refreshCenter = refreshCenter
    }

    var defaultCategories: [CustomCategory] {
        myCategories
            .filter(\.isDefault)
            .sorted(by: defaultCategorySort)
    }

    var ownCustomCategories: [CustomCategory] {
        myCategories
            .filter { !$0.isDefault && $0.isOwnedByCurrentUser }
            .sorted(by: ownCategorySort)
    }

    var addedFriendCategories: [CustomCategory] {
        myCategories
            .filter { !$0.isDefault && !$0.isOwnedByCurrentUser }
            .sorted(by: addedFriendCategorySort)
    }

    var availableFriendCategories: [CustomCategory] {
        friendCategories
            .sorted(by: friendCategorySort)
    }

    var hiddenDefaultCategories: [CustomCategory] {
        hiddenCategories
            .filter(\.isDefault)
            .sorted(by: hiddenCategorySort)
    }

    func clearError() {
        errorMessage = nil
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
        await performMutation(categoryID: category.id) {
            _ = try await self.categoryRepository.updateCategory(id: category.id, name: name)
        }
    }

    func adoptCategory(_ category: CustomCategory) async {
        _ = await performMutation(categoryID: category.id) {
            _ = try await self.categoryRepository.adoptCategory(id: category.id)
        }
    }

    func hideCategory(_ category: CustomCategory) async {
        _ = await performMutation(categoryID: category.id) {
            _ = try await self.categoryRepository.hideCategory(id: category.id)
        }
    }

    func deleteCategory(_ category: CustomCategory) async {
        _ = await performMutation(categoryID: category.id) {
            try await self.categoryRepository.deleteCategory(id: category.id)
        }
    }

    func unhideCategory(_ category: CustomCategory) async {
        _ = await performMutation(categoryID: category.id) {
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
            self.friendCategories = friendCategories
            self.hiddenCategories = hiddenCategories
            hasLoadedCategories = true
        } catch {
            errorMessage = AppError.wrap(error).errorDescription
        }
    }

    private func performMutation(
        categoryID: UUID? = nil,
        _ action: @escaping () async throws -> Void
    ) async -> Bool {
        guard !isSubmitting else {
            return false
        }

        isSubmitting = true
        submittingCategoryID = categoryID
        errorMessage = nil
        defer {
            isSubmitting = false
            submittingCategoryID = nil
        }

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
        let lhsIsRestaurants = lhs.id == TrustMapCategory.restaurantsCategoryID
        let rhsIsRestaurants = rhs.id == TrustMapCategory.restaurantsCategoryID
        if lhsIsRestaurants != rhsIsRestaurants {
            return lhsIsRestaurants
        }

        let nameComparison = lhs.name.localizedStandardCompare(rhs.name)
        if nameComparison != .orderedSame {
            return nameComparison == .orderedAscending
        }

        return lhs.id.uuidString < rhs.id.uuidString
    }

    private func ownCategorySort(lhs: CustomCategory, rhs: CustomCategory) -> Bool {
        let nameComparison = lhs.name.localizedStandardCompare(rhs.name)
        if nameComparison != .orderedSame {
            return nameComparison == .orderedAscending
        }

        return lhs.id.uuidString < rhs.id.uuidString
    }

    private func addedFriendCategorySort(lhs: CustomCategory, rhs: CustomCategory) -> Bool {
        let ownerComparison = (lhs.ownerDisplayName ?? "").localizedStandardCompare(rhs.ownerDisplayName ?? "")
        if ownerComparison != .orderedSame {
            return ownerComparison == .orderedAscending
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
        defaultCategorySort(lhs: lhs, rhs: rhs)
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

    var helperText: String {
        switch kind {
        case .create:
            return "Custom categories can be discovered and added by your friends."
        case .edit:
            return "Changes apply for everyone who has added this category."
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
    let helperText: String
    let isSaving: Bool
    let errorMessage: String?
    let onSave: @MainActor (String) async -> Bool

    init(
        title: String,
        actionTitle: String,
        helperText: String,
        initialName: String,
        isSaving: Bool,
        errorMessage: String?,
        onSave: @escaping @MainActor (String) async -> Bool
    ) {
        self.title = title
        self.actionTitle = actionTitle
        self.helperText = helperText
        self.isSaving = isSaving
        self.errorMessage = errorMessage
        self.onSave = onSave
        _name = State(initialValue: initialName)
    }

    var body: some View {
        Form {
            Section("Category") {
                TextField("Name", text: $name)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()

                if let validationMessage {
                    Text(validationMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Section {
                Text(helperText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
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
                        save()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var validationMessage: String? {
        if trimmedName.isEmpty {
            return "Enter a category name."
        }

        if trimmedName.count > 120 {
            return "Category name must be 120 characters or fewer."
        }

        return nil
    }

    private var canSave: Bool {
        validationMessage == nil && !isSaving
    }

    private func save() {
        guard canSave else {
            return
        }

        Task {
            if await onSave(trimmedName) {
                dismiss()
            }
        }
    }
}

private struct CategorySection<RowContent: View>: View {
    let title: String
    let categories: [CustomCategory]
    let emptyMessage: String
    let rowContent: (CustomCategory) -> RowContent

    init(
        title: String,
        categories: [CustomCategory],
        emptyMessage: String,
        @ViewBuilder rowContent: @escaping (CustomCategory) -> RowContent
    ) {
        self.title = title
        self.categories = categories
        self.emptyMessage = emptyMessage
        self.rowContent = rowContent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProfileSectionHeader(title: title)

            ProfileCardGroup {
                if categories.isEmpty {
                    CategoryEmptyCard(message: emptyMessage)
                } else {
                    ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                        rowContent(category)

                        if index < categories.count - 1 {
                            CategoryCardDivider()
                        }
                    }
                }
            }
        }
    }
}

private struct CategoryRow<TrailingContent: View>: View {
    let category: CustomCategory
    let subtitle: String?
    let trailingContent: () -> TrailingContent

    init(
        category: CustomCategory,
        subtitle: String? = nil,
        @ViewBuilder trailingContent: @escaping () -> TrailingContent = { EmptyView() }
    ) {
        self.category = category
        self.subtitle = subtitle
        self.trailingContent = trailingContent
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(category.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(1)

                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .layoutPriority(1)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)

            Spacer(minLength: 8)

            trailingContent()
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var accessibilityLabel: String {
        if let subtitle {
            return "\(category.name), \(subtitle)"
        }

        return category.name
    }
}

private struct CategoryActionButton: View {
    enum Style {
        case primary
        case secondary
    }

    let title: String
    let categoryName: String
    let style: Style
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text(title)
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1)
                }
            }
            .foregroundStyle(foregroundStyle)
            .frame(minWidth: 68, minHeight: 34)
            .padding(.horizontal, 2)
            .background(backgroundStyle, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(borderStyle, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled && !isLoading ? 0.55 : 1)
        .accessibilityLabel("\(title) \(categoryName)")
    }

    private var foregroundStyle: Color {
        switch style {
        case .primary:
            return Color.accentColor
        case .secondary:
            return Color.primary.opacity(0.82)
        }
    }

    private var backgroundStyle: Color {
        switch style {
        case .primary:
            return Color.accentColor.opacity(0.10)
        case .secondary:
            return Color(uiColor: .tertiarySystemFill)
        }
    }

    private var borderStyle: Color {
        switch style {
        case .primary:
            return Color.accentColor.opacity(0.18)
        case .secondary:
            return Color.primary.opacity(0.06)
        }
    }
}

private struct CategoryEmptyCard: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel(message)
    }
}

private struct CategoryCardDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 16)
            .accessibilityHidden(true)
    }
}
