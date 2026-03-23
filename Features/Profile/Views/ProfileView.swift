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

                                Text(user.bio ?? "Private foodie mapping their favorite spots.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                Text("Joined \(user.createdAt.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        LabeledContent("Rated Places", value: "\(viewModel.stats.ratedPlacesCount)")
                        LabeledContent("Reviewed Dishes", value: "\(viewModel.stats.reviewedDishesCount)")
                    }

                    Section("My Place Reviews") {
                        if viewModel.placeReviews.isEmpty {
                            Text("You haven’t reviewed any places yet.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(viewModel.placeReviews, id: \.id) { review in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(viewModel.placeNames[review.placeId] ?? "Place")
                                        Text(review.reviewText)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    RatingBadgeView(rating: Double(review.ratingOverall))
                                }
                            }
                        }
                    }

                    Section("My Dish Reviews") {
                        if viewModel.dishReviews.isEmpty {
                            Text("You haven’t reviewed any dishes yet.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(viewModel.dishReviews, id: \.id) { review in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(review.dishName)
                                        Spacer()
                                        RatingBadgeView(rating: Double(review.dishRating))
                                    }
                                    Text(viewModel.placeNames[review.placeId] ?? "Place")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
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
