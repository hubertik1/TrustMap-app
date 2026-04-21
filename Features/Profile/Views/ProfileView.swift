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
                List {
                    Section {
                        HStack(spacing: 16) {
                            AvatarView(name: user.displayName, avatarURL: user.avatarURL, size: 72)

                            VStack(alignment: .leading, spacing: 6) {
                                Text(user.displayName)
                                    .font(.title3.weight(.semibold))

                                Text("@\(user.handle)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                if let bio = user.bio?.trimmingCharacters(in: .whitespacesAndNewlines),
                                   !bio.isEmpty {
                                    Text(bio)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                Button("Edit Profile") {
                                    viewModel.prepareProfileEditor()
                                    isPresentingEditProfile = true
                                }
                                .buttonStyle(.bordered)
                                .padding(.top, 6)
                            }
                        }
                    }

                    Section {
                        NavigationLink {
                            FriendsView(container: container)
                        } label: {
                            ProfileFriendsCard(summary: viewModel.friendsSummary)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                        .listRowBackground(Color.clear)
                    }

                    Section {
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
                            LabeledContent("Rated Places", value: "\(viewModel.stats.ratedPlacesCount)")
                        }

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
                            LabeledContent("Reviewed Dishes", value: "\(viewModel.stats.reviewedDishesCount)")
                        }

                        NavigationLink {
                            CategoriesView(
                                categoryRepository: container.categoryRepository,
                                refreshCenter: container.refreshCenter
                            )
                        } label: {
                            LabeledContent("Categories", value: "\(viewModel.categoryCount)")
                        }
                    }

                    Section {
                        NavigationLink("Settings") {
                            SettingsView(container: container)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            } else {
                EmptyStateView(
                    title: "Profile Unavailable",
                    message: "TrustMap could not load your account data yet. Pull to retry or reopen the app.",
                    systemImage: "person.crop.circle.badge.exclamationmark"
                )
            }
        }
        .navigationTitle("Profile")
        .task(id: refreshCenter.globalRevision) {
            await viewModel.load()
        }
        .sheet(isPresented: $isPresentingEditProfile) {
            NavigationStack {
                ProfileEditorSheet(viewModel: viewModel)
            }
        }
    }
}

private struct ProfileFriendsCard: View {
    let summary: ProfileViewModel.FriendsSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Label("Friends", systemImage: "person.2.fill")
                    .font(.headline)

                Spacer()

                Text(summary.friendCount.formatted())
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                if summary.pendingRequestCount > 0 {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                }

                Text(summary.secondaryText)
                    .font(.subheadline)
                    .foregroundStyle(summary.pendingRequestCount > 0 ? .primary : .secondary)
            }

            if !summary.previewFriends.isEmpty {
                HStack(spacing: -8) {
                    ForEach(summary.previewFriends) { friend in
                        AvatarView(name: friend.displayName, avatarURL: friend.avatarURL, size: 28)
                            .overlay(
                                Circle()
                                    .stroke(Color(uiColor: .systemGroupedBackground), lineWidth: 2)
                            )
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }
}

private struct ProfileEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ProfileViewModel
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        Form {
            Section("Profile") {
                VStack(alignment: .leading, spacing: 16) {
                    profilePhotoEditor

                    Divider()

                    TextField(
                        text: $viewModel.editedDisplayName,
                        prompt: Text("Display name").foregroundStyle(.secondary)
                    ) {
                        EmptyView()
                    }
                    .textFieldStyle(.plain)
                    .font(.body)
                    .textInputAutocapitalization(.words)

                    Divider()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Unique username")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        UniqueUsernameFieldRow(
                            usernameBase: $viewModel.editedHandle,
                            suffix: viewModel.editedHandleSuffix,
                            isInvalid: viewModel.usernameErrorMessage != nil
                        )

                        Text("Only the left part can be changed. The 4-digit suffix is assigned automatically.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        if let usernameErrorMessage = viewModel.usernameErrorMessage {
                            Text(usernameErrorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }

                    Divider()

                    TextField("Bio", text: $viewModel.editedBio, axis: .vertical)
                        .lineLimit(3...5)
                }
                .listRowSeparator(.hidden)
            }
        }
        .disabled(viewModel.isSavingProfile)
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: selectedPhotoItem) {
            await prepareSelectedPhoto(from: selectedPhotoItem)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
                .disabled(viewModel.isSavingProfile)
            }

            ToolbarItem(placement: .confirmationAction) {
                if viewModel.isSavingProfile {
                    ProgressView()
                } else {
                    Button("Save") {
                        Task {
                            let didSave = await viewModel.saveProfileChanges()
                            if didSave {
                                dismiss()
                            }
                        }
                    }
                    .disabled(!viewModel.canSaveProfile)
                }
            }
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

    private var profilePhotoEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                avatarPreview

                VStack(alignment: .leading, spacing: 8) {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label(viewModel.selectedAvatarPhoto == nil && viewModel.editedAvatarURL == nil ? "Choose Photo" : "Change Photo", systemImage: "photo")
                    }
                    .buttonStyle(.borderedProminent)

                    if viewModel.selectedAvatarPhoto != nil || viewModel.editedAvatarURL != nil {
                        Button("Remove Photo", role: .destructive) {
                            selectedPhotoItem = nil
                            viewModel.removeAvatar()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            Text("Your profile photo appears anywhere TrustMap currently shows your initials.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
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
                    size: 84
                )
            }
        }
        .frame(width: 84, height: 84)
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(Color(uiColor: .separator).opacity(0.3), lineWidth: 1)
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

private struct UniqueUsernameFieldRow: View {
    @Binding var usernameBase: String
    let suffix: String
    let isInvalid: Bool

    private var displayedSuffix: String {
        suffix.isEmpty ? "Assigned automatically" : suffix
    }

    var body: some View {
        HStack(spacing: 0) {
            TextField(
                text: $usernameBase,
                prompt: Text("username").foregroundStyle(.secondary)
            ) {
                EmptyView()
            }
            .textFieldStyle(.plain)
            .font(.body)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .textContentType(.username)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .accessibilityLabel("Username base")
            .accessibilityHint("Editable part of your unique username.")

            Rectangle()
                .fill(Color(uiColor: .separator).opacity(0.35))
                .frame(width: 1)
                .padding(.vertical, 10)

            Text(displayedSuffix)
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(minWidth: 84, alignment: .center)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                .accessibilityElement()
                .accessibilityLabel("Automatic suffix")
                .accessibilityValue(suffix.isEmpty ? "Assigned automatically" : suffix)
                .accessibilityHint("System managed and read only.")
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isInvalid ? Color.red.opacity(0.8) : Color(uiColor: .separator).opacity(0.18))
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
            if viewModel.isLoading && viewModel.defaultCategories.isEmpty {
                LoadingStateView(title: "Loading categories")
            } else if let errorMessage = viewModel.errorMessage,
                      viewModel.defaultCategories.isEmpty {
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
                                    subtitle: "Available in TrustMap",
                                    trailingText: category.id == TrustMapCategory.restaurantsCategoryID ? "Places" : "Catalog"
                                )
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Categories")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
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
}

@MainActor
private final class CategoriesViewModel: ObservableObject {
    @Published private(set) var myCategories: [CustomCategory] = []
    @Published var isLoading = false
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
            .sorted { lhs, rhs in
                if lhs.id == TrustMapCategory.restaurantsCategoryID {
                    return true
                }

                if rhs.id == TrustMapCategory.restaurantsCategoryID {
                    return false
                }

                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }

    func load() async {
        errorMessage = nil
        isLoading = true

        do {
            myCategories = try await categoryRepository.fetchMyCategories()
        } catch {
            errorMessage = AppError.wrap(error).errorDescription
        }

        isLoading = false
    }
}

private struct CategoryListRow: View {
    let category: CustomCategory
    let subtitle: String
    let trailingText: String?

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(category.name)
                    .font(.body.weight(.semibold))

                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let trailingText {
                Text(trailingText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.secondarySystemBackground), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
