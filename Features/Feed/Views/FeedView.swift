import SwiftUI

struct FeedView: View {
    private let container: AppContainer
    @ObservedObject private var refreshCenter: AppRefreshCenter
    @StateObject private var viewModel: FeedViewModel
    @State private var selectedPlace: Place?
    @State private var selectedFilter: FeedFilter = .all

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
                feedContent
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Activity Feed")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: refreshCenter.globalRevision) {
            await viewModel.load()
        }
        .navigationDestination(item: $selectedPlace) { place in
            PlaceDetailView(container: container, place: place)
        }
    }

    private var filteredFeedItems: [FeedPlaceActivityItem] {
        viewModel.feedItems.filter(selectedFilter.includes)
    }

    private var feedContent: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if filteredFeedItems.isEmpty {
                    FeedFilteredEmptyStateView()
                        .padding(.top, 24)
                } else {
                    ForEach(filteredFeedItems) { item in
                        FeedActivityCard(item: item) {
                            selectedPlace = item.place
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 36)
        }
        .refreshable {
            await viewModel.load()
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            FeedFilterBar(selectedFilter: $selectedFilter)
                .background(Color(uiColor: .systemGroupedBackground))
        }
    }
}

private enum FeedFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case places = "Places"
    case dishes = "Dishes"
    case photos = "Photos"
    case highRated = "4.0+"

    var id: Self { self }

    func includes(_ item: FeedPlaceActivityItem) -> Bool {
        switch self {
        case .all:
            return true
        case .places:
            return item.activityKind == .placeReview
        case .dishes:
            return item.activityKind == .dishReview
        case .photos:
            return !item.photos.isEmpty
        case .highRated:
            return item.rating >= 4
        }
    }
}

private struct FeedFilterBar: View {
    @Binding var selectedFilter: FeedFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(FeedFilter.allCases) { filter in
                    FeedFilterChip(
                        title: filter.rawValue,
                        isSelected: selectedFilter == filter
                    ) {
                        selectedFilter = filter
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }
}

private struct FeedFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor.opacity(0.14) : Color(uiColor: .secondarySystemGroupedBackground))
                )
                .overlay {
                    Capsule()
                        .stroke(
                            isSelected ? Color.accentColor.opacity(0.35) : Color.primary.opacity(0.06),
                            lineWidth: 1
                        )
                }
        }
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct FeedActivityCard: View {
    let item: FeedPlaceActivityItem
    let onSelect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            VStack(alignment: .leading, spacing: 7) {
                Text(item.headlineText)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                if let placeDetailText = item.place.secondaryDisplayText {
                    Text(placeDetailText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let title = item.feedTitleText {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let body = item.feedBodyText {
                    Text(body)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !item.photos.isEmpty {
                PhotoGridView(
                    assets: item.photos,
                    thumbnailSize: CGSize(width: 86, height: 86),
                    cornerRadius: 16,
                    spacing: 8
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.035), radius: 10, x: 0, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onTapGesture(perform: onSelect)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens place details")
        .accessibilityAction {
            onSelect()
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            AvatarView(
                name: item.author.displayName,
                avatarURL: item.author.avatarURL,
                size: 44
            )
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.author.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text("\(item.activityText) - \(item.createdAt.feedTimestampText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            RatingBadgeView(rating: Double(item.rating))
        }
    }
}

private struct FeedFilteredEmptyStateView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(Color(uiColor: .tertiarySystemFill))
                )

            VStack(spacing: 4) {
                Text("No matching activity")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("Try a different filter.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }
}

private extension FeedPlaceActivityItem {
    var activityText: String {
        switch activityKind {
        case .placeReview:
            return "Reviewed a place"
        case .dishReview:
            return "Reviewed a dish"
        }
    }

    var headlineText: String {
        switch activityKind {
        case .placeReview:
            return place.displayName
        case .dishReview:
            if let dishName = dishName?.feedNonEmptyText {
                return "\(dishName) at \(place.displayName)"
            }

            return "Dish at \(place.displayName)"
        }
    }

    var feedTitleText: String? {
        title?.feedNonEmptyText
    }

    var feedBodyText: String? {
        body.feedNonEmptyText
    }
}

private extension String {
    var feedNonEmptyText: String? {
        let trimmedText = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedText.isEmpty ? nil : trimmedText
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
