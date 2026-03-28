import SwiftUI

struct ProfileView: View {
    @ObservedObject private var container: AppContainer
    @StateObject private var viewModel: ProfileViewModel

    init(container: AppContainer) {
        self.container = container
        _viewModel = StateObject(
            wrappedValue: ProfileViewModel(
                sessionStore: container.sessionStore,
                userRepository: container.userRepository,
                categoryRepository: container.categoryRepository,
                placeRepository: container.placeRepository,
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

                                if let bio = user.bio?.trimmingCharacters(in: .whitespacesAndNewlines),
                                   !bio.isEmpty {
                                    Text(bio)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                Text("Joined \(user.createdAt.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Section {
                        NavigationLink {
                            MyPlaceReviewsView(
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
                            CategoriesView(container: container)
                        } label: {
                            LabeledContent("Categories", value: "\(viewModel.stats.categoriesCount)")
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
        .onAppear {
            Task { await viewModel.load() }
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView(container: PreviewAppFactory.makeContainer())
    }
}

struct CategoriesView: View {
    @StateObject private var viewModel: CategoriesViewModel
    @State private var isAddCategoryPresented = false
    @State private var newCategoryName = ""
    @State private var categoryPendingDeletion: CustomCategory?

    init(container: AppContainer) {
        _viewModel = StateObject(
            wrappedValue: CategoriesViewModel(
                sessionStore: container.sessionStore,
                categoryRepository: container.categoryRepository,
                friendRepository: container.friendRepository,
                userRepository: container.userRepository
            )
        )
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.myCategories.isEmpty && viewModel.hiddenCategories.isEmpty && viewModel.friendCategories.isEmpty {
                LoadingStateView(title: "Loading categories")
            } else if let errorMessage = viewModel.errorMessage,
                      viewModel.myCategories.isEmpty,
                      viewModel.hiddenCategories.isEmpty,
                      viewModel.friendCategories.isEmpty {
                ErrorStateView(message: errorMessage) {
                    Task { await viewModel.load() }
                }
            } else {
                List {
                    Section("My Categories") {
                        if viewModel.myCategories.isEmpty {
                            Text("No visible categories yet.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(viewModel.myCategories, id: \.id) { category in
                                categoryRow(category)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        if viewModel.canHide(category) {
                                            Button("Hide") {
                                                Task { await viewModel.hideCategory(category) }
                                            }
                                            .tint(.gray)
                                        }

                                        if viewModel.canDelete(category) {
                                            Button("Delete", role: .destructive) {
                                                categoryPendingDeletion = category
                                            }
                                        }
                                    }
                            }
                        }
                    }

                    if !viewModel.hiddenCategories.isEmpty {
                        Section("Hidden") {
                            ForEach(viewModel.hiddenCategories, id: \.id) { category in
                                categoryRow(category)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button("Show") {
                                            Task { await viewModel.unhideCategory(category) }
                                        }
                                        .tint(.green)
                                    }
                            }
                        }
                    }

                    Section("Friends' Categories") {
                        if viewModel.friendCategories.isEmpty {
                            Text("No friend categories available to add right now.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(viewModel.friendCategories) { suggestion in
                                friendCategoryRow(suggestion)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Categories")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    newCategoryName = ""
                    isAddCategoryPresented = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add category")
            }
        }
        .task {
            await viewModel.load()
        }
        .alert("New Category", isPresented: $isAddCategoryPresented) {
            TextField("Category Name", text: $newCategoryName)

            Button("Add") {
                let name = newCategoryName
                newCategoryName = ""
                Task { await viewModel.createCategory(named: name) }
            }

            Button("Cancel", role: .cancel) {
                newCategoryName = ""
            }
        } message: {
            Text("Create a category you can use in reviews and filters.")
        }
        .alert("Delete Category?", isPresented: isDeleteAlertPresented) {
            Button("Delete", role: .destructive) {
                guard let categoryPendingDeletion else {
                    return
                }

                let category = categoryPendingDeletion
                self.categoryPendingDeletion = nil
                Task { await viewModel.deleteCategory(category) }
            }

            Button("Cancel", role: .cancel) {
                categoryPendingDeletion = nil
            }
        } message: {
            Text("This removes the category and all places assigned to it in your app.")
        }
        .alert(
            "Unable to Update Categories",
            isPresented: isShowingError
        ) {
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var isDeleteAlertPresented: Binding<Bool> {
        Binding(
            get: { categoryPendingDeletion != nil },
            set: { if !$0 { categoryPendingDeletion = nil } }
        )
    }

    private var isShowingError: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil && !(viewModel.myCategories.isEmpty && viewModel.hiddenCategories.isEmpty && viewModel.friendCategories.isEmpty) },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private func categoryRow(_ category: CustomCategory) -> some View {
        HStack(spacing: 12) {
            Image(systemName: category.iconName ?? "square.grid.2x2")
                .foregroundStyle(.secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 4) {
                Text(category.name)
                    .foregroundStyle(.primary)

                if let secondaryLabel = viewModel.secondaryLabel(for: category) {
                    Text(secondaryLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func friendCategoryRow(_ suggestion: FriendCategorySuggestion) -> some View {
        HStack(spacing: 12) {
            Image(systemName: suggestion.category.iconName ?? "square.grid.2x2")
                .foregroundStyle(.secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.category.name)
                    .foregroundStyle(.primary)

                Text("By \(suggestion.ownerName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Add") {
                Task { await viewModel.importCategory(suggestion) }
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 4)
    }
}
