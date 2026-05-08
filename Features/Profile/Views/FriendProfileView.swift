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
            if !viewModel.hasLoadedProfile && (viewModel.isLoading || viewModel.errorMessage == nil) {
                LoadingStateView(title: "Loading profile")
            } else if !viewModel.hasLoadedProfile || viewModel.user == nil {
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
                if user.canViewProfile {
                    profileContent(for: user)
                } else {
                    privateProfileContent(for: user)
                }
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
                    if user.canViewReviews {
                        UserReviewsView(
                            user: user,
                            placeReviews: viewModel.placeReviews,
                            dishReviews: viewModel.dishReviews,
                            placeNames: viewModel.placeNames,
                            mode: .places
                        )
                    } else {
                        PrivateProfileSectionView.reviews
                    }
                } dishesDestination: {
                    if user.canViewReviews {
                        UserReviewsView(
                            user: user,
                            placeReviews: viewModel.placeReviews,
                            dishReviews: viewModel.dishReviews,
                            placeNames: viewModel.placeNames,
                            mode: .dishes
                        )
                    } else {
                        PrivateProfileSectionView.reviews
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

    private func privateProfileContent(for user: User) -> some View {
        ScrollView {
            VStack(spacing: 14) {
                AvatarView(name: user.displayName, avatarURL: user.avatarURL, size: 82)
                    .overlay {
                        Circle()
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    }

                VStack(spacing: 5) {
                    Text(user.displayName)
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)

                    Text("@\(user.handle)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                VStack(spacing: 6) {
                    Text("This profile is private.")
                        .font(.headline)
                    Text("This user doesn’t allow you to view their profile.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.top, 56)
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
