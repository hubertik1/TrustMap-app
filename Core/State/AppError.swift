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
            return message
        case .invalidSession:
            return "Your session could not be restored."
        case .missingCurrentUser:
            return "No signed-in user is available."
        case .invalidPlaceSelection:
            return "Select a place before continuing."
        case .locationFailure(let message):
            return message
        case .persistenceFailure(let message):
            return message
        case .rateLimited(let message):
            return message
        case .syncFailure(let message):
            return message
        case .validationFailure(let message):
            return message
        case .underlying(let message):
            return message
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
                return .syncFailure("Could not connect to the server.")
            default:
                break
            }
        }

        return .underlying(error.localizedDescription)
    }
}
