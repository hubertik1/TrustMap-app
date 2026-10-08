import Foundation

struct DishReviewCurrency: Equatable, Sendable {
    let code: String
    let symbol: String

    init(
        countryCode: String?,
        existingCurrencyCode: String? = nil,
        fallbackLocale: Locale = .current
    ) {
        let locale = Self.locale(for: countryCode) ?? fallbackLocale
        code = Self.normalizedCode(existingCurrencyCode)
            ?? locale.currency?.identifier
            ?? fallbackLocale.currency?.identifier
            ?? "USD"

        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        symbol = formatter.currencySymbol ?? code
    }

    static func locale(for countryCode: String?) -> Locale? {
        guard let countryCode = normalizedCode(countryCode),
              countryCode.count == 2 else {
            return nil
        }

        // Use the country's default language so local symbols such as zł and Kč
        // are displayed instead of the ISO currency code.
        let language = Locale.Language(identifier: "und_\(countryCode)")
        let locale = Locale(identifier: language.maximalIdentifier)
        guard locale.region?.identifier == countryCode, locale.currency != nil else {
            return nil
        }
        return locale
    }

    static func normalizedCode(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue.uppercased()
    }
}
