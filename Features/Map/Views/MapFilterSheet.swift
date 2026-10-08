import SwiftUI

struct MapFilterSheet: View {
    @Binding var filterState: MapFilterState
    let categoryOptions: [PlaceCategoryOption]
    let onApply: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.filters) {
                    Picker(L10n.addedBy, selection: $filterState.selectedOwnershipFilter) {
                        ForEach(PlaceOwnershipFilter.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }

                    Picker(L10n.category, selection: $filterState.selectedCategory) {
                        ForEach(categoryOptions) { option in
                            Text(option.title).tag(option)
                        }
                    }
                }

                Section(L10n.ratingRange) {
                    Stepper(
                        L10n.minimumRatingValue(String(describing: RatingDisplayFormatter.rating(filterState.minimumRating))),
                        value: $filterState.minimumRating,
                        in: 1...filterState.maximumRating
                    )
                    Stepper(
                        L10n.maximumRatingValue(String(describing: RatingDisplayFormatter.rating(filterState.maximumRating))),
                        value: $filterState.maximumRating,
                        in: filterState.minimumRating...5
                    )
                }

                Section {
                    Button(L10n.resetFilters, role: .destructive) {
                        filterState = .defaultState
                    }
                }
            }
            .navigationTitle(L10n.mapFilters)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.close) { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.apply) {
                        onApply()
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    MapFilterSheet(
        filterState: .constant(MapFilterState()),
        categoryOptions: [.all],
        onApply: {}
    )
}
