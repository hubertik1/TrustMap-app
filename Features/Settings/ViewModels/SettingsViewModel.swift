import Combine
import CoreLocation
import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    private let sessionStore: SessionStore
    private let preferencesStore: AppPreferencesStore
    private let refreshCenter: AppRefreshCenter
    private let userRepository: UserProfileRepository
    private let userLocationService: UserLocationServicing
    private var cancellables = Set<AnyCancellable>()

    @Published private(set) var locationAuthorizationStatus: CLAuthorizationStatus
    @Published private(set) var isSigningOut = false
    @Published private(set) var isUpdatingFriendsPrivacy = false
    @Published var privacyErrorMessage: String?

    init(
        sessionStore: SessionStore,
        preferencesStore: AppPreferencesStore,
        refreshCenter: AppRefreshCenter,
        userRepository: UserProfileRepository,
        userLocationService: UserLocationServicing
    ) {
        self.sessionStore = sessionStore
        self.preferencesStore = preferencesStore
        self.refreshCenter = refreshCenter
        self.userRepository = userRepository
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

    var friendsVisibleToOthers: Bool {
        currentUser?.friendsVisibleToOthers ?? true
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

    func setFriendsVisibleToOthers(_ isVisible: Bool) async {
        guard !isUpdatingFriendsPrivacy else { return }
        guard friendsVisibleToOthers != isVisible else {
            privacyErrorMessage = nil
            return
        }

        isUpdatingFriendsPrivacy = true
        privacyErrorMessage = nil
        defer { isUpdatingFriendsPrivacy = false }

        do {
            let updatedUser = try await userRepository.updateFriendListVisibility(isVisible)
            sessionStore.updateCurrentUser(updatedUser)
            refreshCenter.invalidateAll()
        } catch {
            privacyErrorMessage = AppError.wrap(error).errorDescription
        }
    }
}
