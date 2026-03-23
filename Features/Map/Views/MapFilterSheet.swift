import SwiftUI

struct MapFilterSheet: View {
    @Binding var filterState: MapFilterState
    let availablePeople: [FilterPerson]
    let onApply: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Visibility") {
                    Picker("Source", selection: $filterState.sourceMode) {
                        ForEach(MapSourceFilterMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }

                    Picker("People", selection: $filterState.peopleMode) {
                        ForEach(PeopleFilterMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                }

                Section("Rating Range") {
                    Stepper("Minimum Rating: \(filterState.minimumRating)", value: $filterState.minimumRating, in: 1...filterState.maximumRating)
                    Stepper("Maximum Rating: \(filterState.maximumRating)", value: $filterState.maximumRating, in: filterState.minimumRating...10)
                }

                Section("Selected People") {
                    if availablePeople.isEmpty {
                        Text("People you can filter by will appear after you add friends.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(availablePeople, id: \.id) { person in
                            Button {
                                toggleSelection(for: person.id)
                            } label: {
                                HStack {
                                    Text(person.name)
                                    Spacer()
                                    if filterState.selectedPersonIDs.contains(person.id) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                            }
                        }
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

    private func toggleSelection(for personID: UUID) {
        if filterState.selectedPersonIDs.contains(personID) {
            filterState.selectedPersonIDs.remove(personID)
        } else {
            filterState.selectedPersonIDs.insert(personID)
        }
    }
}

private struct MapFilterSheetPreviewHost: View {
    @State private var filterState = MapFilterState(
        sourceMode: .mineAndFriends,
        minimumRating: 6,
        maximumRating: 10,
        peopleMode: .includeSelected,
        selectedPersonIDs: [UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!]
    )

    var body: some View {
        MapFilterSheet(
            filterState: $filterState,
            availablePeople: PreviewAppFactory.samplePeople(),
            onApply: {}
        )
    }
}

#Preview {
    MapFilterSheetPreviewHost()
}
