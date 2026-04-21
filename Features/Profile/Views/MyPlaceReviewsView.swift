import SwiftUI

struct MyPlaceReviewsView: View {
    @ObservedObject private var container: AppContainer
    let reviews: [PlaceReview]
    let placeNames: [UUID: String]
    let onDelete: @MainActor (PlaceReview) async throws -> Void

    @State private var deletingReviewIDs: Set<UUID> = []
    @State private var deletionErrorMessage: String?

    init(
        container: AppContainer,
        reviews: [PlaceReview],
        placeNames: [UUID: String],
        onDelete: @escaping @MainActor (PlaceReview) async throws -> Void
    ) {
        self.container = container
        self.reviews = reviews
        self.placeNames = placeNames
        self.onDelete = onDelete
    }

    var body: some View {
        Group {
            if reviews.isEmpty {
                ProductEmptyStateView(
                    title: "No rated places yet",
                    message: "Places you review will appear here.",
                    systemImage: "mappin.and.ellipse",
                    primaryActionTitle: "Add Review",
                    onPrimaryAction: {
                        container.selectedTab = .add
                    }
                )
            } else {
                List {
                    ForEach(reviews, id: \.id) { review in
                        NavigationLink {
                            AddPlaceReviewView(
                                container: container,
                                place: review.place,
                                existingReview: review
                            )
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(placeNames[review.placeId] ?? "Place")
                                        .font(.headline)

                                    if !review.descriptionText.isEmpty {
                                        Text(review.descriptionText)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }

                                    Text(review.updatedAt, style: .relative)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer(minLength: 12)

                                RatingBadgeView(rating: Double(review.ratingOverall))
                            }
                            .padding(.vertical, 4)
                            .opacity(deletingReviewIDs.contains(review.id) ? 0.5 : 1)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    delete(review)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .disabled(deletingReviewIDs.contains(review.id))
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("My Place Reviews")
        .alert("Couldn't Delete Review", isPresented: isShowingDeletionError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deletionErrorMessage ?? "")
        }
    }

    private var isShowingDeletionError: Binding<Bool> {
        Binding(
            get: { deletionErrorMessage != nil },
            set: { if !$0 { deletionErrorMessage = nil } }
        )
    }

    private func delete(_ review: PlaceReview) {
        guard !deletingReviewIDs.contains(review.id) else {
            return
        }

        deletingReviewIDs.insert(review.id)

        Task {
            do {
                try await onDelete(review)
            } catch {
                deletionErrorMessage = AppError.wrap(error).errorDescription
            }

            deletingReviewIDs.remove(review.id)
        }
    }
}

#Preview {
    NavigationStack {
        MyPlaceReviewsView(
            container: PreviewAppFactory.makeContainer(),
            reviews: [
                PlaceReview(
                    placeId: UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!,
                    ratingOverall: 9,
                    reviewText: "",
                    descriptionText: "Great coffee, quick service, and plenty of seating."
                    ,
                    author: PreviewAppFactory.sampleUser.summary,
                    place: Place(
                        id: UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!,
                        name: "Caffe Aurora",
                        latitude: 37.7764,
                        longitude: -122.4231,
                        address: "123 Valencia St, San Francisco, CA",
                        city: "San Francisco",
                        countryCode: "US"
                    )
                )
            ],
            placeNames: [
                UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!: "Caffè Aurora"
            ],
            onDelete: { _ in }
        )
    }
}
