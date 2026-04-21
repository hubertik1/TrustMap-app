import SwiftUI

struct FeedView: View {
    private let container: AppContainer
    @ObservedObject private var refreshCenter: AppRefreshCenter
    @StateObject private var viewModel: FeedViewModel

    init(container: AppContainer) {
        self.container = container
        self.refreshCenter = container.refreshCenter
        _viewModel = StateObject(
            wrappedValue: FeedViewModel(
                feedRepository: container.feedRepository
            )
        )
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                LoadingStateView(title: "Loading activity")
            } else if let errorMessage = viewModel.errorMessage {
                ErrorStateView(message: errorMessage) {
                    Task { await viewModel.load() }
                }
            } else if viewModel.feedItems.isEmpty {
                ProductEmptyStateView(
                    title: "No activity yet",
                    message: "Reviews from you and your friends will appear here.",
                    systemImage: "bell.badge",
                    primaryActionTitle: "Add Review",
                    onPrimaryAction: {
                        container.selectedTab = .add
                    }
                )
            } else {
                List(viewModel.feedItems) { item in
                    NavigationLink {
                        PlaceDetailView(container: container, place: item.place)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.title)
                                .font(.headline)

                            if let subtitle = item.subtitle {
                                Text(subtitle)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }

                            FeedStarRatingView(rating: item.rating)

                            Text(item.createdAt.feedTimestampText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable {
                    await viewModel.load()
                }
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Feed")
        .task(id: refreshCenter.globalRevision) {
            await viewModel.load()
        }
    }
}

private extension Date {
    var feedTimestampText: String {
        let elapsedSeconds = max(0, Int(Date.now.timeIntervalSince(self)))
        let minutes = elapsedSeconds / 60

        if minutes < 60 {
            return "\(minutes) min"
        }

        let hours = minutes / 60
        if hours < 24 {
            return "\(hours) h"
        }

        let days = hours / 24
        return "\(days) d"
    }
}

#Preview {
    NavigationStack {
        FeedView(container: PreviewAppFactory.makeContainer())
    }
}

private struct FeedStarRatingView: View {
    let rating: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(star <= rating ? Color.yellow : Color.secondary.opacity(0.45))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rating")
        .accessibilityValue("\(rating) out of 5 stars")
    }
}
