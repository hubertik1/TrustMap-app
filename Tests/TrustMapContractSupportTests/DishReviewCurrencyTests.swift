import Foundation
import XCTest
@testable import TrustMapContractSupport

final class DishReviewCurrencyTests: XCTestCase {
    func testRestaurantCountryOverridesPhoneRegion() {
        let polishPhoneLocale = Locale(identifier: "pl_PL")
        let examples = [
            (country: "US", code: "USD", symbol: "$"),
            (country: "DE", code: "EUR", symbol: "€"),
            (country: "GB", code: "GBP", symbol: "£"),
            (country: "JP", code: "JPY", symbol: "¥"),
            (country: "CA", code: "CAD", symbol: "$")
        ]

        for example in examples {
            let currency = DishReviewCurrency(
                countryCode: example.country,
                fallbackLocale: polishPhoneLocale
            )

            XCTAssertEqual(currency.code, example.code, example.country)
            XCTAssertEqual(currency.symbol, example.symbol, example.country)
        }
    }

    func testLocalCurrencySymbolsAndCountryNormalization() {
        let currency = DishReviewCurrency(
            countryCode: " pl \n",
            fallbackLocale: Locale(identifier: "en_US")
        )

        XCTAssertEqual(currency.code, "PLN")
        XCTAssertEqual(currency.symbol, "zł")
        XCTAssertEqual(DishReviewCurrency(countryCode: "CZ").symbol, "Kč")
        XCTAssertEqual(DishReviewCurrency(countryCode: "UA").symbol, "₴")
    }

    func testEditingPreservesSavedCurrencyEvenInAnotherCountry() {
        let currency = DishReviewCurrency(
            countryCode: "PL",
            existingCurrencyCode: " eur \n",
            fallbackLocale: Locale(identifier: "en_US")
        )

        XCTAssertEqual(currency.code, "EUR")
        XCTAssertEqual(currency.symbol, "€")
    }

    func testMissingOrInvalidCountryUsesFallbackLocale() {
        for country in [nil, "", " \n", "XX", "Poland"] as [String?] {
            let currency = DishReviewCurrency(
                countryCode: country,
                fallbackLocale: Locale(identifier: "pl_PL")
            )

            XCTAssertEqual(currency.code, "PLN")
            XCTAssertEqual(currency.symbol, "zł")
        }
    }

    func testEmptySavedCurrencyDoesNotOverrideRestaurantCountry() {
        let currency = DishReviewCurrency(
            countryCode: "US",
            existingCurrencyCode: " \n",
            fallbackLocale: Locale(identifier: "pl_PL")
        )

        XCTAssertEqual(currency.code, "USD")
        XCTAssertEqual(currency.symbol, "$")
    }
}
