import Combine
import CoreLocation
import Foundation
import OSLog

@MainActor
final class SettingsViewModel: ObservableObject {
    private let sessionStore: SessionStore
    private let preferencesStore: AppPreferencesStore
    private let refreshCenter: AppRefreshCenter
    private let userRepository: UserProfileRepository
    private let userLocationService: UserLocationServicing
    private let logger = Logger(subsystem: "TrustMap", category: "SettingsPrivacy")
    private var cancellables = Set<AnyCancellable>()

    @Published private(set) var locationAuthorizationStatus: CLAuthorizationStatus
    @Published private(set) var isSigningOut = false
    @Published private(set) var isUpdatingPrivacy = false
    @Published private(set) var reviewVisibility: VisibilityStatus = .friendsOnly
    @Published private(set) var friendListVisibility: VisibilityStatus = .friendsOnly
    @Published private(set) var profileVisibility: VisibilityStatus = .public
    @Published private(set) var profilePictureVisibility: VisibilityStatus = .public
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
        syncPrivacySettings(with: sessionStore.currentUser)

        sessionStore.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if !self.isUpdatingPrivacy {
                        self.syncPrivacySettings(with: self.sessionStore.currentUser)
                    }
                    self.objectWillChange.send()
                }
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

    var supportsPrivacySettings: Bool {
        currentUser?.supportsPrivacySettings ?? false
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

    func setReviewVisibility(_ value: VisibilityStatus) {
        updatePrivacy(reviewVisibility: value)
    }

    func setFriendListVisibility(_ value: VisibilityStatus) {
        updatePrivacy(friendListVisibility: value)
    }

    func setProfileVisibility(_ value: VisibilityStatus) {
        updatePrivacy(profileVisibility: value)
    }

    func setProfilePictureVisibility(_ value: VisibilityStatus) {
        updatePrivacy(profilePictureVisibility: value)
    }

    private func updatePrivacy(
        reviewVisibility nextReviewVisibility: VisibilityStatus? = nil,
        friendListVisibility nextFriendListVisibility: VisibilityStatus? = nil,
        profileVisibility nextProfileVisibility: VisibilityStatus? = nil,
        profilePictureVisibility nextProfilePictureVisibility: VisibilityStatus? = nil
    ) {
        guard !isUpdatingPrivacy else { return }
        guard supportsPrivacySettings else {
            privacyErrorMessage = "Privacy settings are not available on this server version."
            logger.warning("Privacy update blocked because current user profile does not include privacy support fields")
            return
        }

        let updatedReviewVisibility = nextReviewVisibility ?? reviewVisibility
        let updatedFriendListVisibility = nextFriendListVisibility ?? friendListVisibility
        let updatedProfileVisibility = nextProfileVisibility ?? profileVisibility
        let updatedProfilePictureVisibility = nextProfilePictureVisibility ?? profilePictureVisibility
        let previousReviewVisibility = reviewVisibility
        let previousFriendListVisibility = friendListVisibility
        let previousProfileVisibility = profileVisibility
        let previousProfilePictureVisibility = profilePictureVisibility

        guard updatedReviewVisibility != reviewVisibility
            || updatedFriendListVisibility != friendListVisibility
            || updatedProfileVisibility != profileVisibility
            || updatedProfilePictureVisibility != profilePictureVisibility else {
            privacyErrorMessage = nil
            return
        }

        privacyErrorMessage = nil
        logger.info(
            "Requesting privacy update review=\(updatedReviewVisibility.rawValue, privacy: .public) friends=\(updatedFriendListVisibility.rawValue, privacy: .public) profile=\(updatedProfileVisibility.rawValue, privacy: .public) photo=\(updatedProfilePictureVisibility.rawValue, privacy: .public)"
        )
        applyPrivacySettings(
            reviewVisibility: updatedReviewVisibility,
            friendListVisibility: updatedFriendListVisibility,
            profileVisibility: updatedProfileVisibility,
            profilePictureVisibility: updatedProfilePictureVisibility
        )
        isUpdatingPrivacy = true

        Task { [weak self] in
            await self?.commitPrivacyUpdate(
                reviewVisibility: updatedReviewVisibility,
                friendListVisibility: updatedFriendListVisibility,
                profileVisibility: updatedProfileVisibility,
                profilePictureVisibility: updatedProfilePictureVisibility,
                previousReviewVisibility: previousReviewVisibility,
                previousFriendListVisibility: previousFriendListVisibility,
                previousProfileVisibility: previousProfileVisibility,
                previousProfilePictureVisibility: previousProfilePictureVisibility
            )
        }
    }

    private func commitPrivacyUpdate(
        reviewVisibility updatedReviewVisibility: VisibilityStatus,
        friendListVisibility updatedFriendListVisibility: VisibilityStatus,
        profileVisibility updatedProfileVisibility: VisibilityStatus,
        profilePictureVisibility updatedProfilePictureVisibility: VisibilityStatus,
        previousReviewVisibility: VisibilityStatus,
        previousFriendListVisibility: VisibilityStatus,
        previousProfileVisibility: VisibilityStatus,
        previousProfilePictureVisibility: VisibilityStatus
    ) async {
        defer { isUpdatingPrivacy = false }
        do {
            let updatedUser = try await userRepository.updatePrivacySettings(
                reviewVisibility: updatedReviewVisibility,
                friendListVisibility: updatedFriendListVisibility,
                profileVisibility: updatedProfileVisibility,
                profilePictureVisibility: updatedProfilePictureVisibility
            )
            sessionStore.updateCurrentUser(updatedUser)
            syncPrivacySettings(with: updatedUser)
            preferencesStore.defaultPlaceReviewVisibility = updatedUser.reviewVisibility.selectableValue
            preferencesStore.defaultDishReviewVisibility = updatedUser.reviewVisibility.selectableValue
            refreshCenter.invalidateAll()
            privacyErrorMessage = nil
            logger.info("Privacy update succeeded")
        } catch {
            let wrappedError = AppError.wrap(error)
            logger.error("Privacy update failed: \(wrappedError.logDescription, privacy: .public)")
            await recoverPrivacyStateAfterFailure(
                requestedReviewVisibility: updatedReviewVisibility,
                requestedFriendListVisibility: updatedFriendListVisibility,
                requestedProfileVisibility: updatedProfileVisibility,
                requestedProfilePictureVisibility: updatedProfilePictureVisibility,
                previousReviewVisibility: previousReviewVisibility,
                previousFriendListVisibility: previousFriendListVisibility,
                previousProfileVisibility: previousProfileVisibility,
                previousProfilePictureVisibility: previousProfilePictureVisibility
            )
        }
    }

    private func recoverPrivacyStateAfterFailure(
        requestedReviewVisibility: VisibilityStatus,
        requestedFriendListVisibility: VisibilityStatus,
        requestedProfileVisibility: VisibilityStatus,
        requestedProfilePictureVisibility: VisibilityStatus,
        previousReviewVisibility: VisibilityStatus,
        previousFriendListVisibility: VisibilityStatus,
        previousProfileVisibility: VisibilityStatus,
        previousProfilePictureVisibility: VisibilityStatus
    ) async {
        do {
            let refreshedUser = try await userRepository.fetchCurrentUser()
            sessionStore.updateCurrentUser(refreshedUser)
            syncPrivacySettings(with: refreshedUser)

            if refreshedUser.reviewVisibility == requestedReviewVisibility
                && refreshedUser.friendListVisibility == requestedFriendListVisibility
                && refreshedUser.profileVisibility == requestedProfileVisibility
                && refreshedUser.profilePictureVisibility == requestedProfilePictureVisibility {
                preferencesStore.defaultPlaceReviewVisibility = refreshedUser.reviewVisibility.selectableValue
                preferencesStore.defaultDishReviewVisibility = refreshedUser.reviewVisibility.selectableValue
                refreshCenter.invalidateAll()
                privacyErrorMessage = nil
                logger.info("Recovered privacy update state from /me after PATCH failure")
            } else {
                privacyErrorMessage = "Couldn’t update privacy settings. Please try again."
                logger.warning("Privacy refresh after failure returned a profile, but it did not confirm requested values")
            }
        } catch {
            applyPrivacySettings(
                reviewVisibility: previousReviewVisibility,
                friendListVisibility: previousFriendListVisibility,
                profileVisibility: previousProfileVisibility,
                profilePictureVisibility: previousProfilePictureVisibility
            )
            privacyErrorMessage = "Couldn’t update privacy settings. Please try again."
            let wrappedError = AppError.wrap(error)
            logger.error("Privacy refresh after failure also failed: \(wrappedError.logDescription, privacy: .public)")
        }
    }

    private func syncPrivacySettings(with user: User?) {
        applyPrivacySettings(
            reviewVisibility: user?.reviewVisibility ?? .friendsOnly,
            friendListVisibility: user?.friendListVisibility ?? .friendsOnly,
            profileVisibility: user?.profileVisibility ?? .public,
            profilePictureVisibility: user?.profilePictureVisibility ?? .public
        )
    }

    private func applyPrivacySettings(
        reviewVisibility: VisibilityStatus,
        friendListVisibility: VisibilityStatus,
        profileVisibility: VisibilityStatus,
        profilePictureVisibility: VisibilityStatus
    ) {
        self.reviewVisibility = reviewVisibility
        self.friendListVisibility = friendListVisibility
        self.profileVisibility = profileVisibility
        self.profilePictureVisibility = profilePictureVisibility
    }
}

private extension AppError {
    var logDescription: String {
        errorDescription ?? "Unknown error"
    }
}
