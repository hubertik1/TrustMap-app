import SwiftUI

struct FriendProfileView: View {
    @ObservedObject private var container: AppContainer
    @ObservedObject private var refreshCenter: AppRefreshCenter
    @StateObject private var viewModel: FriendProfileViewModel

    init(container: AppContainer, userID: UUID, initialUser: UserSummary? = nil) {
        self.container = container
        self.refreshCenter = container.refreshCenter
        _viewModel = StateObject(
            wrappedValue: FriendProfileViewModel(
                userID: userID,
                initialUser: initialUser,
                userRepository: container.userRepository,
                placeReviewRepository: container.placeReviewRepository,
                dishReviewRepository: container.dishReviewRepository
            )
        )
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.user == nil {
                LoadingStateView(title: "Loading profile")
            } else if viewModel.user == nil {
                ProductEmptyStateView(
                    title: "Profile unavailable",
                    message: "We couldn't load this profile.",
                    systemImage: "person.crop.circle.badge.exclamationmark",
                    primaryActionTitle: "Try Again",
                    onPrimaryAction: {
                        Task { await viewModel.load() }
                    }
                )
            } else if let user = viewModel.user {
                profileContent(for: user)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: refreshCenter.globalRevision) {
            await viewModel.load()
        }
    }

    private func profileContent(for user: User) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                if let errorMessage = viewModel.errorMessage {
                    InlineErrorBanner(title: "Couldn't refresh profile", message: errorMessage) {
                        Task { await viewModel.load() }
                    }
                }

                if let reviewsErrorMessage = viewModel.reviewsErrorMessage {
                    InlineErrorBanner(title: "Couldn't load all reviews", message: reviewsErrorMessage) {
                        Task { await viewModel.load() }
                    }
                }

                ProfileHeroCard(
                    user: user,
                    friendCount: user.friendCount,
                    pendingRequestCount: 0,
                    ratedPlacesCount: user.visiblePlaceReviewCount,
                    reviewedDishesCount: user.visibleDishReviewCount,
                    onEditProfile: nil,
                    canNavigateToFriends: user.canViewFriends
                ) {
                    if user.canViewFriends {
                        UserFriendsView(container: container, user: user)
                    } else {
                        FriendListPrivacyStateView()
                    }
                } placesDestination: {
                    UserReviewsView(
                        user: user,
                        placeReviews: viewModel.placeReviews,
                        dishReviews: viewModel.dishReviews,
                        placeNames: viewModel.placeNames,
                        mode: .places
                    )
                } dishesDestination: {
                    UserReviewsView(
                        user: user,
                        placeReviews: viewModel.placeReviews,
                        dishReviews: viewModel.dishReviews,
                        placeNames: viewModel.placeNames,
                        mode: .dishes
                    )
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
}

#Preview {
    NavigationStack {
        FriendProfileView(
            container: PreviewAppFactory.makeContainer(),
            userID: PreviewAppFactory.sampleUser.id,
            initialUser: PreviewAppFactory.sampleUser.summary
        )
    }
}
