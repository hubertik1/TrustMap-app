import Foundation
import XCTest
@testable import TrustMapContractSupport

final class LocalizationTests: XCTestCase {
    private var catalogURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/Localizable.xcstrings")
    }

    private func languageBundle(_ language: String) throws -> Bundle {
        let url = try XCTUnwrap(L10n.resourceBundle.url(forResource: language, withExtension: "lproj"))
        return try XCTUnwrap(Bundle(url: url))
    }

    func testEveryCatalogKeyIsAvailableInEveryCompiledLanguage() throws {
        let data = try Data(contentsOf: catalogURL)
        let catalog = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try XCTUnwrap(catalog["strings"] as? [String: Any])
        for language in L10n.supportedLanguages {
            let bundle = try languageBundle(language)
            for (key, entry) in strings {
                if (entry as? [String: Any])?["shouldTranslate"] as? Bool == false { continue }
                let missing = "__missing_translation__"
                let value = bundle.localizedString(forKey: key, value: missing, table: "Localizable")
                XCTAssertNotEqual(value, missing, "Missing \(language) translation for \(key)")
                XCTAssertFalse(value.isEmpty, "Empty \(language) translation for \(key)")
            }
        }
    }

    func testNavigationTranslationsUseRequestedLanguage() throws {
        let expected = ["en": "Settings", "pl": "Ustawienia", "de": "Einstellungen", "es": "Ajustes",
                        "fr": "Réglages", "it": "Impostazioni", "pt": "Definições", "uk": "Налаштування"]
        for (language, title) in expected {
            XCTAssertEqual(try languageBundle(language).localizedString(forKey: "ui.settings", value: nil, table: "Localizable"), title)
        }
    }

    func testPushLocalizationKeysResolveInEveryAppLanguageAndPreserveUserNames() throws {
        let namedKeys = ["ui.value_added_a_place_review", "ui.value_added_a_dish_review", "ui.value_sent_you_a_friend_request"]
        let anonymousKeys = ["push.place_review_added_unknown_actor", "push.dish_review_added_unknown_actor",
                             "push.friend_request_sent_unknown_actor", "push.new_notification"]
        let actor = "@100%_Żółć_東京"
        for language in L10n.supportedLanguages {
            let bundle = try languageBundle(language)
            for key in namedKeys {
                let template = bundle.localizedString(forKey: key, value: nil, table: "Localizable")
                XCTAssertNotEqual(template, key)
                let message = String(format: template, locale: Locale(identifier: language), actor)
                XCTAssertTrue(message.contains(actor), "\(language): user names must remain literal")
                XCTAssertFalse(message.contains("%@"))
                if language != "en" {
                    let english = try languageBundle("en").localizedString(forKey: key, value: nil, table: "Localizable")
                    XCTAssertNotEqual(template, english, "\(language): push must not fall back to English")
                }
            }
            for key in anonymousKeys {
                let message = bundle.localizedString(forKey: key, value: nil, table: "Localizable")
                XCTAssertNotEqual(message, key)
                XCTAssertFalse(message.contains("%@"))
                XCTAssertFalse(message.isEmpty)
                if language != "en" { XCTAssertFalse(message.contains("Someone")) }
            }
        }
    }

    func testPushMessagesUseSpanishAndPolishAppTranslations() throws {
        let cases = [
            ("es", "ui.value_added_a_place_review", "@ana añadió una reseña de un lugar"),
            ("es", "ui.value_added_a_dish_review", "@ana añadió una reseña de un plato"),
            ("es", "ui.value_sent_you_a_friend_request", "@ana te envió una solicitud de amistad"),
            ("pl", "ui.value_added_a_place_review", "@ana dodaje opinię o miejscu"),
            ("pl", "ui.value_added_a_dish_review", "@ana dodaje opinię o daniu"),
            ("pl", "ui.value_sent_you_a_friend_request", "@ana wysyła Ci zaproszenie do znajomych")
        ]
        for (language, key, expected) in cases {
            let template = try languageBundle(language).localizedString(forKey: key, value: nil, table: "Localizable")
            XCTAssertEqual(String(format: template, locale: Locale(identifier: language), "@ana"), expected)
        }
    }

    func testNativePluralRulesForPolishAndUkrainian() throws {
        let examples = [
            ("en", [1: "1 review", 2: "2 reviews", 5: "5 reviews"]),
            ("pl", [1: "1 opinia", 2: "2 opinie", 5: "5 opinii", 12: "12 opinii", 22: "22 opinie"]),
            ("uk", [1: "1 відгук", 2: "2 відгуки", 5: "5 відгуків", 12: "12 відгуків", 22: "22 відгуки"])
        ]
        for (language, examples) in examples {
            let template = try languageBundle(language).localizedString(forKey: "count.reviews", value: nil, table: "Localizable")
            for (count, expected) in examples {
                XCTAssertEqual(String(format: template, locale: Locale(identifier: language), Int64(count)), expected)
            }
        }
    }

    func testPluralWithNamePreservesArgumentOrder() throws {
        let bundle = try languageBundle("pl")
        let template = bundle.localizedString(forKey: "count.other_contributors_reviewed", value: nil, table: "Localizable")
        XCTAssertEqual(String(format: template, locale: Locale(identifier: "pl"), "Anna", Int64(2)), "Anna i 2 inne osoby oceniają")
    }

    func testCustomCategoryNamesArePreserved() {
        XCTAssertEqual(DefaultCategoryCatalog.displayName(for: "Moje ulubione kawiarnie"), "Moje ulubione kawiarnie")
        XCTAssertEqual(DefaultCategoryCatalog.restaurantsCanonicalName, "Restaurants")
        XCTAssertTrue(DefaultCategoryCatalog.isRestaurantsName("Restaurants"))
    }

    func testBackendMessagesAreLocalizedOnlyForDisplay() throws {
        let raw = "Place not found."
        let error = AppError.validationFailure(raw)
        guard case .validationFailure(let stored) = error else { return XCTFail("Wrong error case") }
        XCTAssertEqual(stored, raw)
        let key = "server.place_not_found.place_not_found"
        XCTAssertEqual(error.errorDescription, L10n.resourceBundle.localizedString(forKey: key, value: nil, table: "Localizable"))
        for language in L10n.supportedLanguages {
            let bundle = try languageBundle(language)
            XCTAssertEqual(L10n.backendMessage(raw, in: bundle), bundle.localizedString(forKey: key, value: nil, table: "Localizable"))
        }
        XCTAssertEqual(L10n.backendMessage(raw, in: try languageBundle("pl")), "Nie znaleziono miejsca.")
        XCTAssertEqual(L10n.backendMessage("Unknown server detail"), "Unknown server detail")
        let displayMessage = try XCTUnwrap(error.errorDescription)
        XCTAssertEqual(L10n.backendMessage(raw + "\n" + raw), [displayMessage, displayMessage].joined(separator: "\n"))
    }
}
