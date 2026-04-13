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
                            AvatarView(name: user.displayName, size: 72)

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

private struct ProfileEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ProfileViewModel

    var body: some View {
        Form {
            Section("Profile") {
                VStack(alignment: .leading, spacing: 10) {
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

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Username base")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextField(
                            text: $viewModel.editedHandle,
                            prompt: Text("username").foregroundStyle(.secondary)
                        ) {
                            EmptyView()
                        }
                        .textFieldStyle(.plain)
                        .font(.body)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    }

                    Divider()

                    LabeledContent("Suffix") {
                        Text(viewModel.editedHandleSuffix.isEmpty ? "Assigned automatically" : viewModel.editedHandleSuffix)
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    Divider()
                }
                .listRowSeparator(.hidden)

                Text("Edit only the username base. The 4-digit suffix is managed automatically.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                TextField("Bio", text: $viewModel.editedBio, axis: .vertical)
                    .lineLimit(3...5)
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
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
}

#Preview {
    NavigationStack {
        ProfileView(container: PreviewAppFactory.makeContainer())
    }
}

private struct CategoriesView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: CategoriesViewModel
    @State private var isPresentingAddCategory = false

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
            if viewModel.isLoading && viewModel.myCategories.isEmpty && viewModel.friendCategories.isEmpty {
                LoadingStateView(title: "Loading categories")
            } else if let errorMessage = viewModel.errorMessage,
                      viewModel.myCategories.isEmpty,
                      viewModel.friendCategories.isEmpty {
                ErrorStateView(message: errorMessage) {
                    Task { await viewModel.load() }
                }
            } else {
                List {
                    Picker("Source", selection: $viewModel.selectedTab) {
                        ForEach(CategoriesViewModel.Tab.allCases) { tab in
                            Text(tab.title).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)

                    switch viewModel.selectedTab {
                    case .mine:
                        if !viewModel.defaultCategories.isEmpty {
                            Section("Default Categories") {
                                ForEach(viewModel.defaultCategories) { category in
                                    CategoryListRow(
                                        category: category,
                                        subtitle: "Available for everyone",
                                        trailingText: "Default"
                                    )
                                }
                            }
                        }

                        Section("Your Categories") {
                            if viewModel.customCategories.isEmpty {
                                Text("Add your first custom category or save one from a friend.")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(viewModel.customCategories) { category in
                                    NavigationLink {
                                        CategoryDetailView(
                                            category: category,
                                            viewModel: viewModel
                                        )
                                    } label: {
                                        CategoryListRow(
                                            category: category,
                                            subtitle: viewModel.subtitle(forMyCategory: category),
                                            trailingText: category.isOwnedByCurrentUser ? "You" : "Saved"
                                        )
                                    }
                                }
                            }
                        }
                    case .friends:
                        Section("Categories from Friends") {
                            if viewModel.friendCategories.isEmpty {
                                Text("No new friend categories to add right now.")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(viewModel.friendCategories) { category in
                                    HStack(spacing: 12) {
                                        CategoryListRow(
                                            category: category,
                                            subtitle: viewModel.subtitle(forFriendCategory: category),
                                            trailingText: nil
                                        )

                                        Button("Add") {
                                            Task { await viewModel.adopt(category) }
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .disabled(viewModel.adoptingCategoryIDs.contains(category.id))
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Categories")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if viewModel.selectedTab == .mine {
                    Button {
                        isPresentingAddCategory = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .task {
            await viewModel.load()
        }
        .sheet(isPresented: $isPresentingAddCategory) {
            NavigationStack {
                AddCategorySheet(viewModel: viewModel)
            }
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
    enum Tab: String, CaseIterable, Identifiable {
        case mine
        case friends

        var id: String { rawValue }

        var title: String {
            switch self {
            case .mine:
                return "My Categories"
            case .friends:
                return "From Friends"
            }
        }
    }

    @Published var selectedTab: Tab = .mine
    @Published private(set) var myCategories: [CustomCategory] = []
    @Published private(set) var friendCategories: [CustomCategory] = []
    @Published private(set) var adoptingCategoryIDs: Set<UUID> = []
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var isDeleting = false
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
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var customCategories: [CustomCategory] {
        myCategories
            .filter { !$0.isDefault }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func load() async {
        errorMessage = nil
        isLoading = true

        do {
            async let mine = categoryRepository.fetchMyCategories()
            async let friends = categoryRepository.fetchFriendCategories()
            myCategories = try await mine
            friendCategories = try await friends
        } catch {
            errorMessage = AppError.wrap(error).errorDescription
        }

        isLoading = false
    }

    func createCategory(named name: String) async -> Bool {
        isSaving = true
        defer { isSaving = false }

        do {
            let created = try await categoryRepository.createCategory(name: name)
            if !myCategories.contains(where: { $0.id == created.id }) {
                myCategories.append(created)
            }
            friendCategories.removeAll { $0.name.caseInsensitiveCompare(created.name) == .orderedSame }
            refreshCenter.invalidateAll()
            return true
        } catch {
            errorMessage = AppError.wrap(error).errorDescription
            return false
        }
    }

    func updateCategory(_ category: CustomCategory, name: String) async -> Bool {
        isSaving = true
        defer { isSaving = false }

        do {
            let updated = try await categoryRepository.updateCategory(id: category.id, name: name)
            if let index = myCategories.firstIndex(where: { $0.id == updated.id }) {
                myCategories[index] = updated
            }
            refreshCenter.invalidateAll()
            return true
        } catch {
            errorMessage = AppError.wrap(error).errorDescription
            return false
        }
    }

    func deleteCategory(_ category: CustomCategory) async -> Bool {
        isDeleting = true
        defer { isDeleting = false }

        do {
            try await categoryRepository.deleteCategory(id: category.id)
            myCategories.removeAll { $0.id == category.id }
            refreshCenter.invalidateAll()
            return true
        } catch {
            errorMessage = AppError.wrap(error).errorDescription
            return false
        }
    }

    func adopt(_ category: CustomCategory) async {
        guard !adoptingCategoryIDs.contains(category.id) else {
            return
        }

        adoptingCategoryIDs.insert(category.id)
        defer { adoptingCategoryIDs.remove(category.id) }

        do {
            let adopted = try await categoryRepository.adoptCategory(id: category.id)
            if !myCategories.contains(where: { $0.id == adopted.id }) {
                myCategories.append(adopted)
            }
            friendCategories.removeAll { $0.id == category.id }
            refreshCenter.invalidateAll()
        } catch {
            errorMessage = AppError.wrap(error).errorDescription
        }
    }

    func subtitle(forMyCategory category: CustomCategory) -> String {
        if category.isOwnedByCurrentUser {
            return "Created by you"
        }

        if let owner = category.owner {
            return "Saved from \(owner.displayName)"
        }

        return "Available in your account"
    }

    func subtitle(forFriendCategory category: CustomCategory) -> String {
        if let owner = category.owner {
            return "@\(owner.handle) · \(owner.displayName)"
        }

        return "Created by a friend"
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

private struct AddCategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: CategoriesViewModel
    @State private var name = ""

    var body: some View {
        Form {
            Section("New Category") {
                TextField("Category name", text: $name)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()

                Text("Default categories stay locked. New categories you add here become available in your own reviews and filters.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Add Category")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }

            ToolbarItem(placement: .confirmationAction) {
                if viewModel.isSaving {
                    ProgressView()
                } else {
                    Button("Save") {
                        Task {
                            let didSave = await viewModel.createCategory(named: name)
                            if didSave {
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

private struct CategoryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let category: CustomCategory
    @ObservedObject var viewModel: CategoriesViewModel

    @State private var name: String
    @State private var isDeleteConfirmationPresented = false

    init(category: CustomCategory, viewModel: CategoriesViewModel) {
        self.category = category
        self.viewModel = viewModel
        _name = State(initialValue: category.name)
    }

    private var isEditable: Bool {
        category.isOwnedByCurrentUser
    }

    var body: some View {
        Form {
            Section("Category") {
                TextField("Title", text: $name)
                    .disabled(!isEditable)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
            }

            Section {
                Button(role: .destructive) {
                    isDeleteConfirmationPresented = true
                } label: {
                    Text("Delete Category")
                }
                .disabled(viewModel.isDeleting)
                .confirmationDialog(
                    "Delete this category?",
                    isPresented: $isDeleteConfirmationPresented,
                    titleVisibility: .visible
                ) {
                    Button("Delete Category", role: .destructive) {
                        Task {
                            let didDelete = await viewModel.deleteCategory(category)
                            if didDelete {
                                dismiss()
                            }
                        }
                    }

                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Are you sure you want to delete this category?")
                }
            } header: {
                Text("Danger Zone")
            }
        }
        .navigationTitle("Category")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if isEditable {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Button("Save") {
                            Task {
                                let didSave = await viewModel.updateCategory(category, name: name)
                                if didSave {
                                    dismiss()
                                }
                            }
                        }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || name == category.name)
                    }
                }
            }
        }
    }
}
