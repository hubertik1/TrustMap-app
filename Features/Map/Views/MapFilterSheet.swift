import SwiftUI

struct MapFilterSheet: View {
    @Binding var filterState: MapFilterState
    let onApply: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
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
    MapFilterSheet(filterState: .constant(MapFilterState()), onApply: {})
}
