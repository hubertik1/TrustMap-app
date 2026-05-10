import SwiftUI

struct NotificationsView: View {
    private let container: AppContainer
    @StateObject private var viewModel: NotificationsViewModel
    @State private var route: NotificationRoute?
    @State private var actionErrorMessage: String?
    @State private var activeNotificationID: UUID?

    init(container: AppContainer) {
        self.container = container
        _viewModel = StateObject(
            wrappedValue: NotificationsViewModel(
                notificationRepository: container.notificationRepository,
                badgeStore: container.notificationBadgeStore
            )
        )
    }

    var body: some View {
        Group {
            if viewModel.isLoading && !viewModel.hasLoaded {
                LoadingStateView(title: "Loading notifications")
            } else if let errorMessage = viewModel.errorMessage, viewModel.notifications.isEmpty {
                ErrorStateView(message: errorMessage) {
                    Task { await viewModel.load() }
                }
            } else if viewModel.isEmpty {
                EmptyStateView(
                    title: "No notifications yet",
                    message: "Friend activity and requests will appear here.",
                    systemImage: "bell"
                )
            } else {
                notificationsList
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
        }
        .toolbar {
            if viewModel.hasUnreadNotifications {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Mark all read") {
                        Task { await viewModel.markAllAsRead() }
                    }
                }
            }
        }
        .navigationDestination(item: $route) { route in
            switch route {
            case .place(let place):
                PlaceDetailView(container: container, place: place)
                    .id(place.id)
            case .friends:
                FriendsView(container: container)
            }
        }
    }

    private var notificationsList: some View {
        List {
            if let actionErrorMessage {
                InlineErrorBanner(
                    title: "Couldn't open notification",
                    message: actionErrorMessage,
                    retryAction: {
                        self.actionErrorMessage = nil
                    }
                )
            }

            if let errorMessage = viewModel.errorMessage {
                InlineErrorBanner(title: "Couldn't refresh notifications", message: errorMessage) {
                    Task { await viewModel.refresh() }
                }
            }

            ForEach(viewModel.notifications) { notification in
                Button {
                    Task { await open(notification) }
                } label: {
                    HStack(spacing: 10) {
                        NotificationRowView(notification: notification)

                        if activeNotificationID == notification.id {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(activeNotificationID != nil)
                .accessibilityHint("Opens notification")
            }
        }
        .listStyle(.insetGrouped)
        .trustMapReadableContent(maxWidth: 760)
        .refreshable {
            await viewModel.refresh()
        }
    }

    private func open(_ notification: TrustMapNotification) async {
        activeNotificationID = notification.id
        defer { activeNotificationID = nil }

        actionErrorMessage = nil
        guard await viewModel.markAsRead(notification) else {
            return
        }

        switch notification.type {
        case .placeReviewAdded:
            guard let placeReviewId = notification.placeReviewId else {
                actionErrorMessage = "This review is no longer available."
                return
            }

            do {
                let review = try await container.placeReviewRepository.fetchReview(id: placeReviewId)
                let placeId = notification.placeId ?? review.placeId
                let details = try await container.placeRepository.fetchPlaceDetails(id: placeId)
                route = .place(details.place)
            } catch {
                guard !Self.isCancellation(error) else { return }
                actionErrorMessage = "This place or review is no longer available."
            }

        case .dishReviewAdded:
            guard let dishReviewId = notification.dishReviewId else {
                actionErrorMessage = "This review is no longer available."
                return
            }

            do {
                let review = try await container.dishReviewRepository.fetchReview(id: dishReviewId)
                let placeId = notification.placeId ?? review.placeId
                let details = try await container.placeRepository.fetchPlaceDetails(id: placeId)
                route = .place(details.place)
            } catch {
                guard !Self.isCancellation(error) else { return }
                actionErrorMessage = "This place or review is no longer available."
            }

        case .friendRequestSent:
            route = .friends
        }
    }

    private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }
}

private enum NotificationRoute: Hashable, Identifiable {
    case place(Place)
    case friends

    var id: String {
        switch self {
        case .place(let place):
            return "place-\(place.id.uuidString)"
        case .friends:
            return "friends"
        }
    }
}

#Preview {
    NavigationStack {
        NotificationsView(container: PreviewAppFactory.makeContainer())
    }
}
