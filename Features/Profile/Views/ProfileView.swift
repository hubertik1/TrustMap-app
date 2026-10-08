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
                LoadingStateView(title: L10n.loadingProfile)
            } else if displayUser == nil {
                ProductEmptyStateView(
                    title: L10n.profileUnavailable,
                    message: L10n.weCouldnTLoadYourAccountData,
                    systemImage: "person.crop.circle.badge.exclamationmark",
                    primaryActionTitle: L10n.tryAgain,
                    onPrimaryAction: {
                        Task { await viewModel.load() }
                    }
                )
            } else if let user = displayUser {
                profileContent(for: user)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(L10n.profile)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: refreshCenter.globalRevision) {
            await viewModel.load()
        }
        .sheet(isPresented: $isPresentingEditProfile) {
            NavigationStack {
                ProfileEditorSheet(viewModel: viewModel)
            }
            .trustMapMacSheet(width: TrustMapLayout.formMaxWidth, minHeight: 700)
        }
    }

    private var displayUser: User? {
        viewModel.user ?? container.sessionStore.currentUser
    }

    private var refreshErrorBanner: some View {
        Group {
            if let errorMessage = viewModel.errorMessage {
                InlineErrorBanner(title: L10n.couldnTRefreshProfile, message: errorMessage) {
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
                    ProfileSectionHeader(title: L10n.network)

                    ProfileCardGroup {
                        NavigationLink {
                            FriendsView(container: container)
                        } label: {
                            ProfileCardRow(
                                icon: "person.2.fill",
                                iconColor: .cyan,
                                title: L10n.friends,
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
                    ProfileSectionHeader(title: L10n.yourActivity)

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
                                title: L10n.ratedPlaces,
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
                                title: L10n.reviewedDishes,
                                value: viewModel.stats.reviewedDishesCount.formatted()
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    ProfileSectionHeader(title: L10n.manage)

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
                                title: L10n.categories,
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
                                title: L10n.settings
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, TrustMapLayout.tabAwareBottomPadding)
            .trustMapReadableContent(
                maxWidth: TrustMapLayout.activityContentMaxWidth,
                alignment: TrustMapPlatform.isMacCatalyst ? .top : .topLeading
            )
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
        L10n.friendsValueValue(String(describing: viewModel.friendsSummary.friendCount.formatted()), String(describing: viewModel.friendsSummary.secondaryText))
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
                    ProfileEditorSectionHeader(title: L10n.profilePhoto)
                    ProfileEditorCard {
                        profilePhotoEditor
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    ProfileEditorSectionHeader(title: L10n.publicProfile)
                    ProfileEditorCard {
                        publicProfileForm
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 40)
            .trustMapReadableContent(maxWidth: TrustMapLayout.formMaxWidth, alignment: .topLeading)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .scrollDismissesKeyboard(.interactively)
        .disabled(viewModel.isSavingProfile)
        .navigationTitle(L10n.editProfile)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: selectedPhotoItem) {
            await loadPendingAvatarCrop(from: selectedPhotoItem)
        }
        #if targetEnvironment(macCatalyst)
        .sheet(item: $pendingAvatarCrop, onDismiss: avatarCropperDidDismiss) { pendingCrop in
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
            .trustMapMacSheet(width: 860, minHeight: 700)
            .id(pendingCrop.id)
        }
        #else
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
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    cancelEditing()
                } label: {
                    ProfileEditorToolbarButtonLabel(title: L10n.cancel)
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
                        ProfileEditorToolbarButtonLabel(title: L10n.save)
                    }
                    .buttonStyle(.plain)
                    .fixedSize(horizontal: true, vertical: false)
                    .foregroundStyle(viewModel.canSaveProfile ? Color.accentColor : Color.secondary)
                    .disabled(!viewModel.canSaveProfile)
                }
            }
        }
        .confirmationDialog(
            L10n.confirmDiscardChanges,
            isPresented: $isShowingDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.discardChanges, role: .destructive) {
                dismiss()
            }

            Button(L10n.keepEditing, role: .cancel) {}
        } message: {
            Text(L10n.yourProfileEditsWonTBeSaved)
        }
        .alert(
            L10n.unableToSaveProfile,
            isPresented: Binding(
                get: { viewModel.errorMessage != nil && pendingAvatarCrop == nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button(L10n.ok, role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var publicProfileForm: some View {
        let usernameMessage = viewModel.localUsernameValidationMessage ?? viewModel.usernameErrorMessage

        return VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                ProfileEditorFieldLabel(L10n.displayName)

                ProfileEditorInputContainer(isInvalid: viewModel.displayNameValidationMessage != nil) {
                    TextField(
                        text: $viewModel.editedDisplayName,
                        prompt: Text(L10n.displayName).foregroundStyle(.secondary)
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
                ProfileEditorFieldLabel(L10n.username)

                UniqueUsernameFieldRow(
                    usernameBase: $viewModel.editedHandle,
                    suffix: viewModel.editedHandleSuffix,
                    isInvalid: usernameMessage != nil
                )

                Text(L10n.onlyTheNameBeforeTheSuffixCanBeChanged)
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
                ProfileEditorFieldLabel(L10n.bio)

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
        let photoButtonTitle = hasEditedPhoto ? L10n.changePhoto : L10n.addPhoto

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
                    Button(L10n.removePhoto, role: .destructive) {
                        selectedPhotoItem = nil
                        pendingAvatarCrop = nil
                        isPreparingCroppedAvatar = false
                        viewModel.removeAvatar()
                    }
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.plain)
                    .accessibilityHint(L10n.removesYourProfilePhoto)
                }
            }

            Text(L10n.yourPhotoAppearsNextToYourReviewsAndActivity)
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
                    name: viewModel.editedDisplayName.isEmpty ? L10n.trustmapMember : viewModel.editedDisplayName,
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
        .accessibilityLabel(L10n.profilePhoto)
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
                throw AppError.validationFailure(L10n.couldnTLoadTheSelectedPhotoTryAnotherImage)
            }

            guard let image = ProfilePhotoCropperImageLoader.image(from: rawData) else {
                throw AppError.validationFailure(L10n.couldnTLoadTheSelectedPhotoTryAnotherImage)
            }

            pendingAvatarCrop = PendingAvatarCrop(image: image)
        } catch is CancellationError {
            return
        } catch {
            viewModel.errorMessage = L10n.couldnTLoadTheSelectedPhotoTryAnotherImage
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
        viewModel.errorMessage = L10n.couldnTPreparePhotoTryAnotherImage
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
                    Text(L10n.tellFriendsWhatKindOfPlacesYouLike)
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
                    .accessibilityLabel(L10n.bioCharacterCount)
                    .accessibilityValue(L10n.valueOfValue(String(describing: characterCount), String(describing: characterLimit)))
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
                    prompt: Text(L10n.username).foregroundStyle(.secondary)
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
                .accessibilityLabel(L10n.username)
                .accessibilityHint(L10n.editablePartOfYourUniqueUsername)

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
                    .accessibilityLabel(L10n.readOnlyAutomaticSuffix)
                    .accessibilityValue(suffix.isEmpty ? L10n.assignedAutomatically : suffix)
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
                LoadingStateView(title: L10n.loadingCategories)
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
        .navigationTitle(L10n.categories)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.clearError()
                    editorPresentation = .create
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(L10n.newCategory)
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
            .trustMapMacSheet(width: 520, minHeight: 360)
        }
        .confirmationDialog(
            L10n.confirmDeleteCategory,
            isPresented: Binding(
                get: { categoryPendingDeletion != nil },
                set: { if !$0 { categoryPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let categoryPendingDeletion {
                Button(L10n.deleteCategory, role: .destructive) {
                    Task {
                        await viewModel.deleteCategory(categoryPendingDeletion)
                        self.categoryPendingDeletion = nil
                    }
                }
            }

            Button(L10n.cancel, role: .cancel) {
                categoryPendingDeletion = nil
            }
        } message: {
            Text(L10n.thisCategoryWillStopBeingAvailableToYouAndYourFriendsExistingReviewsWillKeepTheirHistory)
        }
    }

    private var categoriesContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                if let errorMessage = viewModel.errorMessage {
                    InlineErrorBanner(title: L10n.couldnTUpdateCategories, message: errorMessage) {
                        Task { await viewModel.load() }
                    }
                }

                CategorySection(
                    title: L10n.defaultCategories,
                    categories: viewModel.defaultCategories,
                    emptyMessage: L10n.noDefaultCategoriesAreAvailableYet
                ) { category in
                    CategoryRow(
                        category: category
                    ) {
                        if category.canHide {
                            CategoryActionButton(
                                title: L10n.hide,
                                categoryName: category.displayName,
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
                    title: L10n.myCategories,
                    categories: viewModel.ownCustomCategories,
                    emptyMessage: L10n.createYourOwnCategoriesToOrganizePlacesYourWay
                ) { category in
                    CategoryRow(
                        category: category,
                        subtitle: L10n.createdByYou
                    ) {
                        if category.canEdit || category.canDelete {
                            ownCategoryMenu(for: category)
                        }
                    }
                }

                CategorySection(
                    title: L10n.addedFromFriends,
                    categories: viewModel.addedFriendCategories,
                    emptyMessage: L10n.categoriesYouAddFromFriendsWillAppearHere
                ) { category in
                    CategoryRow(
                        category: category,
                        subtitle: addedFriendSubtitle(for: category)
                    ) {
                        if category.canHide {
                            CategoryActionButton(
                                title: L10n.remove,
                                categoryName: category.displayName,
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
                    title: L10n.categoriesFromFriends,
                    categories: viewModel.availableFriendCategories,
                    emptyMessage: L10n.friendCategoriesYouHavenTAddedYetWillShowUpHere
                ) { category in
                    CategoryRow(
                        category: category,
                        subtitle: availableFriendSubtitle(for: category)
                    ) {
                        if category.canAdopt {
                            CategoryActionButton(
                                title: L10n.add,
                                categoryName: category.displayName,
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
                    title: L10n.hiddenDefaultCategories,
                    categories: viewModel.hiddenDefaultCategories,
                    emptyMessage: L10n.defaultCategoriesYouHideWillAppearHereSoYouCanRestoreThemLater
                ) { category in
                    CategoryRow(
                        category: category,
                        subtitle: L10n.hiddenOnlyForYou
                    ) {
                        if category.canUnhide {
                            CategoryActionButton(
                                title: L10n.show,
                                categoryName: category.displayName,
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
            .padding(.bottom, TrustMapLayout.tabAwareBottomPadding)
            .trustMapReadableContent(maxWidth: TrustMapLayout.activityContentMaxWidth, alignment: .topLeading)
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
                    Label(L10n.edit, systemImage: "pencil")
                }
                .accessibilityLabel(L10n.editValue(String(describing: category.displayName)))
            }

            if category.canDelete {
                Button(role: .destructive) {
                    categoryPendingDeletion = category
                } label: {
                    Label(L10n.delete, systemImage: "trash")
                }
                .accessibilityLabel(L10n.deleteValue(String(describing: category.displayName)))
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
        .accessibilityLabel(L10n.categoryActionsForValue(String(describing: category.displayName)))
    }

    private func addedFriendSubtitle(for category: CustomCategory) -> String {
        if let ownerName = friendOwnerName(for: category) {
            return L10n.addedFromValue(String(describing: ownerName))
        }

        return L10n.addedFromAFriend
    }

    private func availableFriendSubtitle(for category: CustomCategory) -> String {
        if let ownerName = friendOwnerName(for: category) {
            return L10n.createdByValue(String(describing: ownerName))
        }

        return L10n.createdByAFriend
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
            return L10n.newCategory
        case .edit:
            return L10n.editCategory
        }
    }

    var actionTitle: String {
        switch kind {
        case .create:
            return L10n.create
        case .edit:
            return L10n.save
        }
    }

    var helperText: String {
        switch kind {
        case .create:
            return L10n.customCategoriesCanBeDiscoveredAndAddedByYourFriends
        case .edit:
            return L10n.changesApplyForEveryoneWhoHasAddedThisCategory
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
            Section(L10n.category) {
                TextField(L10n.name, text: $name)
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
                Button(L10n.cancel) { dismiss() }
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
            return L10n.enterACategoryName
        }

        if trimmedName.count > 120 {
            return L10n.categoryNameMustBe120CharactersOrFewer
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
                Text(category.displayName)
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
            return "\(category.displayName), \(subtitle)"
        }

        return category.displayName
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
