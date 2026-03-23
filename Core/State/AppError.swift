import Foundation

enum AppError: LocalizedError {
    case authFailed(String)
    case invalidSession
    case missingCurrentUser
    case invalidPlaceSelection
    case locationFailure(String)
    case persistenceFailure(String)
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
        case .syncFailure(let message):
            return message
        case .validationFailure(let message):
            return message
        case .underlying(let message):
            return message
        }
    }

    static func wrap(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }

        return .underlying(error.localizedDescription)
    }
}
