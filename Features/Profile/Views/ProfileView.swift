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
        .task {
            await viewModel.load()
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView(container: PreviewAppFactory.makeContainer())
    }
}
