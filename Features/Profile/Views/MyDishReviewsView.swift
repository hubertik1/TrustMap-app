import SwiftUI

struct MyDishReviewsView: View {
    let reviews: [DishReview]
    let placeNames: [UUID: String]
    let onDelete: @MainActor (DishReview) async throws -> Void

    @State private var deletingReviewIDs: Set<UUID> = []
    @State private var deletionErrorMessage: String?

    var body: some View {
        Group {
            if reviews.isEmpty {
                EmptyStateView(
                    title: "No Dish Reviews Yet",
                    message: "Your saved dish reviews will show up here.",
                    systemImage: "fork.knife.circle"
                )
            } else {
                List {
                    ForEach(reviews, id: \.id) { review in
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
            reviews: [
                DishReview(
                    placeId: UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!,
                    authorUserId: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
                    dishName: "Tiramisu Pancakes",
                    dishCategory: "Dessert Brunch",
                    dishRating: 10,
                    dishReviewText: "Ridiculously good mascarpone cream.",
                    price: 14
                )
            ],
            placeNames: [
                UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!: "Caffè Aurora"
            ],
            onDelete: { _ in }
        )
    }
}
