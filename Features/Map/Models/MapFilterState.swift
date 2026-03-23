import Foundation

struct MapFilterState: Equatable, Sendable {
    var selectedCategoryOption: PlaceCategoryOption = .restaurants
    var sourceMode: ReviewSourceFilterMode = .mineAndFriends
    var minimumRating: Int = 1
    var maximumRating: Int = 10
    var peopleMode: PeopleFilterMode = .allVisible
    var selectedPersonIDs: Set<UUID> = []

    var ratingRange: ClosedRange<Int> {
        minimumRating...maximumRating
    }

    var summaryText: String {
        var components: [String] = [selectedCategoryOption.title, sourceMode.displayName]
        if minimumRating > 1 || maximumRating < 10 {
            components.append("\(minimumRating)-\(maximumRating)/10")
        }

        switch peopleMode {
        case .allVisible:
            break
        case .includeSelected:
            components.append(selectedPersonIDs.isEmpty ? "No people selected" : "Only selected people")
        case .excludeSelected:
            components.append(selectedPersonIDs.isEmpty ? "No exclusions" : "Excluding selected people")
        }

        return components.joined(separator: " • ")
    }

    func resolvedAuthorIDs(currentUserID: UUID, friendIDs: Set<UUID>) -> Set<UUID> {
        let baseIDs: Set<UUID>

        switch sourceMode {
        case .mineOnly:
            baseIDs = [currentUserID]
        case .friendsOnly:
            baseIDs = friendIDs
        case .mineAndFriends:
            baseIDs = friendIDs.union([currentUserID])
        }

        switch peopleMode {
        case .allVisible:
            return baseIDs
        case .includeSelected:
            return baseIDs.intersection(selectedPersonIDs)
        case .excludeSelected:
            return baseIDs.subtracting(selectedPersonIDs)
        }
    }
}
