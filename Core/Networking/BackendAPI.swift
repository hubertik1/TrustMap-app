import Foundation

struct EmptyResponse: Decodable, Sendable {
    init() {}
}

struct AnyEncodable: Encodable {
    private let encoderClosure: (Encoder) throws -> Void

    init<T: Encodable>(_ wrapped: T) {
        encoderClosure = wrapped.encode(to:)
    }

    func encode(to encoder: Encoder) throws {
        try encoderClosure(encoder)
    }
}

private struct ProblemDetailsResponse: Decodable {
    let type: String?
    let title: String?
    let status: Int?
    let detail: String?
    let errors: [String: [String]]?

    var bestMessage: String {
        let validationMessages = errors?
            .values
            .flatMap { $0 }
            .joined(separator: "\n")

        if let validationMessages, !validationMessages.isEmpty {
            return validationMessages
        }

        if let detail, !detail.isEmpty {
            return detail
        }

        if let title, !title.isEmpty {
            return title
        }

        return "The server returned an unexpected response."
    }
}

enum HTTPMethod: String, Sendable {
    case delete = "DELETE"
    case get = "GET"
    case patch = "PATCH"
    case post = "POST"
}

enum RequestBody {
    case json(AnyEncodable)
    case multipart(MultipartFormData)
}

struct APIRequest<Response: Decodable> {
    let method: HTTPMethod
    let path: String
    var queryItems: [URLQueryItem] = []
    var headers: [String: String] = [:]
    var body: RequestBody?
    var requiresAuthorization = true
    var retriesAfterUnauthorized = true
    var acceptedStatusCodes: Set<Int> = [200]
}

struct MultipartFormData: Sendable {
    struct File: Sendable {
        let fieldName: String
        let fileName: String
        let mimeType: String
        let data: Data
    }

    let boundary: String
    let payload: Data

    init(fields: [String: String], file: File) {
        let boundary = "Boundary-\(UUID().uuidString)"
        var data = Data()

        for field in fields.sorted(by: { $0.key < $1.key }) {
            data.append("--\(boundary)\r\n")
            data.append("Content-Disposition: form-data; name=\"\(field.key)\"\r\n\r\n")
            data.append("\(field.value)\r\n")
        }

        data.append("--\(boundary)\r\n")
        data.append("Content-Disposition: form-data; name=\"\(file.fieldName)\"; filename=\"\(file.fileName)\"\r\n")
        data.append("Content-Type: \(file.mimeType)\r\n\r\n")
        data.append(file.data)
        data.append("\r\n")
        data.append("--\(boundary)--\r\n")

        self.boundary = boundary
        self.payload = data
    }

    var contentType: String {
        "multipart/form-data; boundary=\(boundary)"
    }
}

private extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }
}

@MainActor
protocol APISessionProviding: AnyObject {
    var currentAccessToken: String? { get }
    func refreshSession() async throws -> String
    func handleUnauthorizedSession() async
}

@MainActor
final class APIClient {
    private let baseURL: URL
    private let urlSession: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    weak var sessionProvider: (any APISessionProviding)?

    init(
        baseURL: URL,
        urlSession: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.urlSession = urlSession

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(decodeBackendDate)
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    func send<Response: Decodable>(_ request: APIRequest<Response>) async throws -> Response {
        do {
            return try await perform(request)
        } catch TransportError.unauthorized where request.requiresAuthorization && request.retriesAfterUnauthorized {
            guard let sessionProvider else {
                throw AppError.invalidSession
            }

            do {
                _ = try await sessionProvider.refreshSession()
            } catch {
                await sessionProvider.handleUnauthorizedSession()
                throw AppError.invalidSession
            }

            var retryRequest = request
            retryRequest.retriesAfterUnauthorized = false
            return try await perform(retryRequest)
        } catch let appError as AppError {
            throw appError
        } catch {
            if Self.isCancellation(error) {
                throw error
            }

            throw AppError.wrap(error)
        }
    }

    private func perform<Response: Decodable>(_ request: APIRequest<Response>) async throws -> Response {
        let urlRequest = try buildURLRequest(for: request)
        let (data, response) = try await urlSession.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.underlying("The server response was invalid.")
        }

        if request.acceptedStatusCodes.contains(httpResponse.statusCode) {
            return try decode(Response.self, from: data)
        }

        if httpResponse.statusCode == 401 {
            throw TransportError.unauthorized
        }

        throw try mapError(statusCode: httpResponse.statusCode, data: data)
    }

    private func buildURLRequest<Response>(for request: APIRequest<Response>) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(request.path), resolvingAgainstBaseURL: false) else {
            throw AppError.underlying("The backend URL is invalid.")
        }

        if !request.queryItems.isEmpty {
            components.queryItems = request.queryItems
        }

        guard let url = components.url else {
            throw AppError.underlying("The backend URL is invalid.")
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.timeoutInterval = AppConfiguration.networkTimeout

        for (header, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: header)
        }

        if request.requiresAuthorization {
            guard let accessToken = sessionProvider?.currentAccessToken, !accessToken.isEmpty else {
                throw AppError.invalidSession
            }

            urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        switch request.body {
        case .json(let encodable):
            urlRequest.httpBody = try encoder.encode(encodable)
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        case .multipart(let multipart):
            urlRequest.httpBody = multipart.payload
            urlRequest.setValue(multipart.contentType, forHTTPHeaderField: "Content-Type")

        case nil:
            break
        }

        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        return urlRequest
    }

    private func decode<Response: Decodable>(_ type: Response.Type, from data: Data) throws -> Response {
        if type == EmptyResponse.self, data.isEmpty {
            return EmptyResponse() as! Response
        }

        if data.isEmpty {
            throw AppError.underlying("The server returned an empty response.")
        }

        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw AppError.underlying("The app could not decode the server response.")
        }
    }

    private func mapError(statusCode: Int, data: Data) throws -> AppError {
        let problem = try? decoder.decode(ProblemDetailsResponse.self, from: data)
        let message = problem?.bestMessage ?? HTTPURLResponse.localizedString(forStatusCode: statusCode)

        switch statusCode {
        case 400, 404, 409, 422:
            return .validationFailure(message)
        case 401:
            return .invalidSession
        case 403:
            return .authFailed(message)
        default:
            return .underlying(message)
        }
    }

    private enum TransportError: Error {
        case unauthorized
    }

    private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }
}

private func decodeBackendDate(from decoder: Decoder) throws -> Date {
    let container = try decoder.singleValueContainer()
    let rawValue = try container.decode(String.self)

    let fractionalFormatter = ISO8601DateFormatter()
    fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]

    let backendDateFormatter = DateFormatter()
    backendDateFormatter.locale = Locale(identifier: "en_US_POSIX")
    backendDateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

    if let date = fractionalFormatter.date(from: rawValue)
        ?? formatter.date(from: rawValue) {
        return date
    }

    let backendFormats = [
        "yyyy-MM-dd'T'HH:mm:ss.SSSSSSS",
        "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
        "yyyy-MM-dd'T'HH:mm:ss.SSSSS",
        "yyyy-MM-dd'T'HH:mm:ss.SSSS",
        "yyyy-MM-dd'T'HH:mm:ss.SSS",
        "yyyy-MM-dd'T'HH:mm:ss.SS",
        "yyyy-MM-dd'T'HH:mm:ss.S",
        "yyyy-MM-dd'T'HH:mm:ss"
    ]

    for format in backendFormats {
        backendDateFormatter.dateFormat = format
        if let date = backendDateFormatter.date(from: rawValue) {
            return date
        }
    }

    if let normalizedDate = formatter.date(from: "\(rawValue)Z") {
        return normalizedDate
    }

    throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(rawValue)")
}
