import SwiftUI

struct MapFilterSheet: View {
    @Binding var filterState: MapFilterState
    let categoryOptions: [PlaceCategoryOption]
    let onApply: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Filters") {
                    Picker("Added by", selection: $filterState.selectedOwnershipFilter) {
                        ForEach(PlaceOwnershipFilter.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }

                    Picker("Category", selection: $filterState.selectedCategory) {
                        ForEach(categoryOptions) { option in
                            Text(option.title).tag(option)
                        }
                    }
                }

                Section("Rating Range") {
                    Stepper(
                        "Minimum Rating: \(RatingDisplayFormatter.rating(filterState.minimumRating))",
                        value: $filterState.minimumRating,
                        in: 1...filterState.maximumRating
                    )
                    Stepper(
                        "Maximum Rating: \(RatingDisplayFormatter.rating(filterState.maximumRating))",
                        value: $filterState.maximumRating,
                        in: filterState.minimumRating...5
                    )
                }

                Section {
                    Button("Reset Filters", role: .destructive) {
                        filterState = .defaultState
                    }
                }
            }
            .navigationTitle("Map Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
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
