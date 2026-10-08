import Foundation

enum DefaultCategoryCatalog {
    static let restaurantsCategoryID = UUID(uuidString: "D53A109F-9617-4A0A-B95A-5AD277A30764")!
    static let restaurantsKey = "restaurants"
    static let restaurantsCanonicalName = "Restaurants"

    static func isRestaurants(categoryID: UUID?, categoryName: String? = nil) -> Bool {
        categoryID == restaurantsCategoryID || isRestaurantsName(categoryName)
    }

    static func isRestaurantsName(_ categoryName: String?) -> Bool {
        guard let normalized = normalizedLookupValue(categoryName) else {
            return false
        }

        return normalized == "restaurant" || normalized == restaurantsKey
    }

    /// Keep canonical/API names stable; translate only their presentation.
    static func displayName(for rawName: String) -> String {
        isRestaurantsName(rawName) ? L10n.restaurants : rawName
    }

    static func canonicalName(for categoryID: UUID?, rawName: String?) -> String? {
        guard let trimmed = rawName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }

        return isRestaurants(categoryID: categoryID, categoryName: trimmed)
            ? restaurantsCanonicalName
            : trimmed
    }

    static func canonicalNames(_ rawNames: [String]) -> [String] {
        var canonicalNames: [String] = []
        var seenKeys = Set<String>()

        for rawName in rawNames {
            guard let canonicalName = canonicalName(for: nil, rawName: rawName),
                  let key = canonicalKey(for: rawName) else {
                continue
            }

            if seenKeys.insert(key).inserted {
                canonicalNames.append(canonicalName)
            }
        }

        return canonicalNames
    }

    static func canonicalKey(for rawName: String?) -> String? {
        guard let normalized = normalizedLookupValue(rawName) else {
            return nil
        }

        return normalized == "restaurant" ? restaurantsKey : normalized
    }

    private static func normalizedLookupValue(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }

        return trimmed
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }
}
