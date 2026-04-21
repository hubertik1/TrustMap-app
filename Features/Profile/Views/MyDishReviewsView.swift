import SwiftUI

struct MyDishReviewsView: View {
    @ObservedObject private var container: AppContainer
    let reviews: [DishReview]
    let placeNames: [UUID: String]
    let onDelete: @MainActor (DishReview) async throws -> Void

    @State private var deletingReviewIDs: Set<UUID> = []
    @State private var deletionErrorMessage: String?

    init(
        container: AppContainer,
        reviews: [DishReview],
        placeNames: [UUID: String],
        onDelete: @escaping @MainActor (DishReview) async throws -> Void
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
                    title: "No reviewed dishes yet",
                    message: "Dishes you review will appear here.",
                    systemImage: "fork.knife.circle.fill",
                    primaryActionTitle: "Add Review",
                    onPrimaryAction: {
                        container.selectedTab = .add
                    }
                )
            } else {
                List {
                    ForEach(reviews, id: \.id) { review in
                        NavigationLink {
                            AddDishReviewView(
                                container: container,
                                place: review.place,
                                existingReview: review
                            )
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(review.dishName)
                                        .font(.headline)

                                    Text(placeNames[review.placeId] ?? "Place")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)

                                    if !review.dishReviewText.isEmpty {
                                        Text(review.dishReviewText)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }

                                    Text(review.updatedAt, style: .relative)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer(minLength: 12)

                                RatingBadgeView(rating: Double(review.dishRating))
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
        .navigationTitle("My Dish Reviews")
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

    private func delete(_ review: DishReview) {
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
        MyDishReviewsView(
            container: PreviewAppFactory.makeContainer(),
            reviews: [
                DishReview(
                    placeId: UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!,
                    dishName: "Tiramisu Pancakes",
                    dishRating: 10,
                    dishReviewText: "Ridiculously good mascarpone cream.",
                    priceAmount: 14,
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
