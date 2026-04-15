import Foundation
import SwiftUI

enum AppMapStylePreference: String, CaseIterable, Identifiable {
    case standard
    case satellite

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standard:
            return "Standard"
        case .satellite:
            return "Satellite"
        }
    }
}

enum AppAppearancePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

@MainActor
final class AppPreferencesStore: ObservableObject {
    @Published var defaultPlaceReviewVisibility: VisibilityStatus {
        didSet {
            userDefaults.set(defaultPlaceReviewVisibility.rawValue, forKey: Keys.defaultPlaceReviewVisibility)
        }
    }

    @Published var defaultDishReviewVisibility: VisibilityStatus {
        didSet {
            userDefaults.set(defaultDishReviewVisibility.rawValue, forKey: Keys.defaultDishReviewVisibility)
        }
    }

    @Published var defaultMapStyle: AppMapStylePreference {
        didSet {
            userDefaults.set(defaultMapStyle.rawValue, forKey: Keys.defaultMapStyle)
        }
    }

    @Published var centerOnUserLocationOnLaunch: Bool {
        didSet {
            userDefaults.set(centerOnUserLocationOnLaunch, forKey: Keys.centerOnUserLocationOnLaunch)
        }
    }

    @Published var appearance: AppAppearancePreference {
        didSet {
            userDefaults.set(appearance.rawValue, forKey: Keys.appearance)
        }
    }

    var preferredColorScheme: ColorScheme? {
        appearance.preferredColorScheme
    }

    private let userDefaults: UserDefaults

    private enum Keys {
        static let defaultPlaceReviewVisibility = "app.preferences.defaultPlaceReviewVisibility"
        static let defaultDishReviewVisibility = "app.preferences.defaultDishReviewVisibility"
        static let defaultMapStyle = "app.preferences.defaultMapStyle"
        static let centerOnUserLocationOnLaunch = "app.preferences.centerOnUserLocationOnLaunch"
        static let appearance = "app.preferences.appearance"
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.defaultPlaceReviewVisibility = (VisibilityStatus(
            rawValue: userDefaults.string(forKey: Keys.defaultPlaceReviewVisibility) ?? ""
        ) ?? .friendsOnly).selectableValue
        self.defaultDishReviewVisibility = (VisibilityStatus(
            rawValue: userDefaults.string(forKey: Keys.defaultDishReviewVisibility) ?? ""
        ) ?? .friendsOnly).selectableValue
        self.defaultMapStyle = AppMapStylePreference(
            rawValue: userDefaults.string(forKey: Keys.defaultMapStyle) ?? ""
        ) ?? .standard
        if userDefaults.object(forKey: Keys.centerOnUserLocationOnLaunch) == nil {
            self.centerOnUserLocationOnLaunch = true
        } else {
            self.centerOnUserLocationOnLaunch = userDefaults.bool(forKey: Keys.centerOnUserLocationOnLaunch)
        }
        self.appearance = AppAppearancePreference(
            rawValue: userDefaults.string(forKey: Keys.appearance) ?? ""
        ) ?? .system
    }
}
