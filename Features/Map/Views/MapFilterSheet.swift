import SwiftUI

struct MapFilterSheet: View {
    @Binding var filterState: MapFilterState
    let categoryOptions: [PlaceCategoryOption]
    let onApply: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Owner") {
                    Picker("Selection", selection: $filterState.selectedOwnershipFilter) {
                        ForEach(PlaceOwnershipFilter.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                }

                Section("Category") {
                    Picker("Selection", selection: $filterState.selectedCategory) {
                        ForEach(categoryOptions) { option in
                            Text(option.title).tag(option)
                        }
                    }
                }

                Section("Rating Range") {
                    Stepper("Minimum Rating: \(filterState.minimumRating)", value: $filterState.minimumRating, in: 1...filterState.maximumRating)
                    Stepper("Maximum Rating: \(filterState.maximumRating)", value: $filterState.maximumRating, in: filterState.minimumRating...5)
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
