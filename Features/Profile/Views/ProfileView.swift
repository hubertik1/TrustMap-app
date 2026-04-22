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
        let hasEditedPhoto = viewModel.selectedAvatarPhoto != nil || viewModel.editedAvatarURL != nil
        let photoButtonTitle = hasEditedPhoto ? "Change Photo" : "Choose Photo"

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                avatarPreview

                VStack(alignment: .leading, spacing: 8) {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label(photoButtonTitle, systemImage: "photo")
                    }
                    .buttonStyle(.borderedProminent)

                    if hasEditedPhoto {
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
