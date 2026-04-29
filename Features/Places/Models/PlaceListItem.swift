import Foundation

struct PlaceListItem: Identifiable, Hashable {
    let id: UUID
    let place: Place
    let averageRating: Double
    let reviewCount: Int
    let contributorCount: Int
    let recentContributors: [UserSummary]
    let latestActivityAtUtc: Date
    let categoryNames: [String]
    let reviewerRatings: [PlaceReviewerRating]
    let createdByUserId: UUID?
    let searchText: String
}

enum PlaceListSearch {
    static func matches(query: String, item: PlaceListItem) -> Bool {
        let tokens = searchTokens(from: query)
        guard !tokens.isEmpty else {
            return true
        }

        let normalizedSearchableText = searchableText(for: item)
        return tokens.allSatisfy { normalizedSearchableText.contains($0) }
    }

    private static func searchableText(for item: PlaceListItem) -> String {
        let values: [String?] = [
            item.place.displayName,
            item.place.name,
            item.place.address,
            item.place.city,
            item.place.countryCode,
            item.categoryNames.joined(separator: " "),
            item.searchText
        ]

        return values
            .compactMap { value in
                let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed?.isEmpty == false ? trimmed : nil
            }
            .joined(separator: " ")
            .placeListNormalizedSearchText
    }

    private static func searchTokens(from query: String) -> [String] {
        query.placeListNormalizedSearchText
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
    }
}

private extension String {
    var placeListNormalizedSearchText: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }
}
