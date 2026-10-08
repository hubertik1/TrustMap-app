import Foundation

enum AppError: LocalizedError {
    case authFailed(String)
    case invalidSession
    case missingCurrentUser
    case invalidPlaceSelection
    case locationFailure(String)
    case persistenceFailure(String)
    case rateLimited(String)
    case syncFailure(String)
    case validationFailure(String)
    case underlying(String)

    var errorDescription: String? {
        switch self {
        case .authFailed(let message):
            return L10n.backendMessage(message)
        case .invalidSession:
            return L10n.yourSessionCouldNotBeRestored
        case .missingCurrentUser:
            return L10n.noSignedInUserIsAvailable
        case .invalidPlaceSelection:
            return L10n.selectAPlaceBeforeContinuing
        case .locationFailure(let message):
            return L10n.backendMessage(message)
        case .persistenceFailure(let message):
            return L10n.backendMessage(message)
        case .rateLimited(let message):
            return L10n.backendMessage(message)
        case .syncFailure(let message):
            return L10n.backendMessage(message)
        case .validationFailure(let message):
            return L10n.backendMessage(message)
        case .underlying(let message):
            return L10n.backendMessage(message)
        }
    }

    var isConnectivityFailure: Bool {
        switch self {
        case .syncFailure:
            return true
        case .authFailed,
             .invalidSession,
             .missingCurrentUser,
             .invalidPlaceSelection,
             .locationFailure,
             .persistenceFailure,
             .rateLimited,
             .validationFailure,
             .underlying:
            return false
        }
    }

    static func wrap(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorTimedOut,
                 NSURLErrorCannotFindHost,
                 NSURLErrorCannotConnectToHost,
                 NSURLErrorDNSLookupFailed,
                 NSURLErrorNetworkConnectionLost,
                 NSURLErrorNotConnectedToInternet,
                 NSURLErrorInternationalRoamingOff,
                 NSURLErrorCallIsActive,
                 NSURLErrorDataNotAllowed,
                 NSURLErrorCannotLoadFromNetwork:
                return .syncFailure(L10n.couldNotConnectToTheServer)
            default:
                break
            }
        }

        return .underlying(error.localizedDescription)
    }
}
