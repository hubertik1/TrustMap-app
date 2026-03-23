import CoreLocation
import Foundation

@MainActor
protocol UserLocationServicing: AnyObject {
    var authorizationStatus: CLAuthorizationStatus { get }
    var currentLocation: CLLocation? { get }
    var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)? { get set }
    var onLocationUpdate: ((CLLocation) -> Void)? { get set }
    var onError: ((AppError) -> Void)? { get set }

    func start()
    func requestCurrentLocation()
}

@MainActor
final class UserLocationService: NSObject, UserLocationServicing {
    var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)?
    var onLocationUpdate: ((CLLocation) -> Void)?
    var onError: ((AppError) -> Void)?

    private let locationManager: CLLocationManager
    private let previewLocation: CLLocation?

    private(set) var authorizationStatus: CLAuthorizationStatus
    private(set) var currentLocation: CLLocation?

    init(locationManager: CLLocationManager = CLLocationManager()) {
        self.locationManager = locationManager
        self.previewLocation = AppConfiguration.isRunningPreviews
            ? CLLocation(latitude: 52.2297, longitude: 21.0122)
            : nil
        self.authorizationStatus = AppConfiguration.isRunningPreviews
            ? .authorizedWhenInUse
            : locationManager.authorizationStatus
        self.currentLocation = previewLocation

        super.init()

        guard !AppConfiguration.isRunningPreviews else {
            return
        }

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func start() {
        if let previewLocation {
            onAuthorizationChange?(.authorizedWhenInUse)
            onLocationUpdate?(previewLocation)
            return
        }

        switch authorizationStatus {
        case .notDetermined:
            authorizationStatus = .notDetermined
            onAuthorizationChange?(authorizationStatus)
            locationManager.requestWhenInUseAuthorization()

        case .authorizedAlways, .authorizedWhenInUse:
            onAuthorizationChange?(authorizationStatus)
            locationManager.requestLocation()

        case .denied, .restricted:
            onAuthorizationChange?(authorizationStatus)

        @unknown default:
            onError?(.locationFailure("TrustMap could not determine the current location permission state."))
        }
    }

    func requestCurrentLocation() {
        if let previewLocation {
            onLocationUpdate?(previewLocation)
            return
        }

        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.requestLocation()

        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()

        case .denied, .restricted:
            onAuthorizationChange?(authorizationStatus)

        @unknown default:
            onError?(.locationFailure("TrustMap could not request your current location."))
        }
    }
}

extension UserLocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus

        Task { @MainActor in
            authorizationStatus = status
            onAuthorizationChange?(authorizationStatus)

            switch status {
            case .authorizedAlways, .authorizedWhenInUse:
                locationManager.requestLocation()
            case .denied, .restricted, .notDetermined:
                break
            @unknown default:
                onError?(.locationFailure("TrustMap could not determine the current location permission state."))
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latestLocation = locations.last else {
            return
        }

        Task { @MainActor in
            currentLocation = latestLocation
            onLocationUpdate?(latestLocation)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let clError = error as? CLError, clError.code == .locationUnknown {
            return
        }

        Task { @MainActor in
            onError?(.locationFailure("TrustMap could not determine your current location."))
        }
    }
}
