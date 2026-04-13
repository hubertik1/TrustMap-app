import Combine
import CoreLocation
import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    private let sessionStore: SessionStore
    private let preferencesStore: AppPreferencesStore
    private let userLocationService: UserLocationServicing
    private var cancellables = Set<AnyCancellable>()

    @Published private(set) var locationAuthorizationStatus: CLAuthorizationStatus
    @Published private(set) var isSigningOut = false

    init(
        sessionStore: SessionStore,
        preferencesStore: AppPreferencesStore,
        userLocationService: UserLocationServicing
    ) {
        self.sessionStore = sessionStore
        self.preferencesStore = preferencesStore
        self.userLocationService = userLocationService
        self.locationAuthorizationStatus = userLocationService.authorizationStatus

        sessionStore.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        preferencesStore.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    var currentUser: User? {
        sessionStore.currentUser
    }

    var buildSummary: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }

    var defaultPlaceReviewVisibility: VisibilityStatus {
        get { preferencesStore.defaultPlaceReviewVisibility }
        set { preferencesStore.defaultPlaceReviewVisibility = newValue }
    }

    var defaultDishReviewVisibility: VisibilityStatus {
        get { preferencesStore.defaultDishReviewVisibility }
        set { preferencesStore.defaultDishReviewVisibility = newValue }
    }

    var defaultMapStyle: AppMapStylePreference {
        get { preferencesStore.defaultMapStyle }
        set { preferencesStore.defaultMapStyle = newValue }
    }

    var centerOnUserLocationOnLaunch: Bool {
        get { preferencesStore.centerOnUserLocationOnLaunch }
        set { preferencesStore.centerOnUserLocationOnLaunch = newValue }
    }

    var appearance: AppAppearancePreference {
        get { preferencesStore.appearance }
        set { preferencesStore.appearance = newValue }
    }

    var locationAccessLabel: String {
        switch locationAuthorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return "On"
        case .denied:
            return "Off"
        case .restricted:
            return "Restricted"
        case .notDetermined:
            return "Not Requested"
        @unknown default:
            return "Off"
        }
    }

    var showsOpenSystemSettings: Bool {
        switch locationAuthorizationStatus {
        case .denied, .restricted:
            return true
        case .authorizedAlways, .authorizedWhenInUse, .notDetermined:
            return false
        @unknown default:
            return false
        }
    }

    var privacyPolicyURL: URL? {
        AppConfiguration.privacyPolicyURL
    }

    var termsOfServiceURL: URL? {
        AppConfiguration.termsOfServiceURL
    }

    func refreshLocationAuthorizationStatus() {
        locationAuthorizationStatus = userLocationService.authorizationStatus
    }

    func signOut() async {
        guard !isSigningOut else { return }
        isSigningOut = true
        defer { isSigningOut = false }
        await sessionStore.signOut()
    }
}
