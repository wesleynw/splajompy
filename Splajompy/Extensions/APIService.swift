import Foundation
@preconcurrency import OpenTelemetryApi

public struct EmptyResponse: Decodable & Sendable {}

public struct RequestResponse<T: Decodable & Sendable>: Decodable, Sendable {
  let success: Bool
  let data: T?
  let error: String?
}

public enum AsyncResult<T: Decodable & Sendable>: Sendable {
  case success(T)
  case error(Error)
}

public struct APIErrorMessage: Error, LocalizedError {
  let message: String

  public var errorDescription: String? {
    return message
  }
}

public struct APIService {
  static let baseUrl: String =
    Bundle.main.object(forInfoDictionaryKey: "API_URL") as? String
    ?? "http://api.splajompy.com"

  private static func createRequest(
    for url: URL,
    method: String = "GET",
    body: Data? = nil
  ) async -> URLRequest {
    var request = URLRequest(url: url)
    request.httpMethod = method

    let token = await AuthManager.shared.getAuthToken()
    if let token = token {
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    if let body = body {
      request.httpBody = body
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }

    request.setValue(
      Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
      forHTTPHeaderField: "X-App-Version"
    )

    return request
  }

  static func performRequest<T: Decodable & Sendable>(
    endpoint: String,
    method: String = "GET",
    queryItems: [URLQueryItem]? = nil,
    body: Data? = nil
  ) async -> AsyncResult<T> {
    let tracer = OpenTelemetry.instance.tracerProvider.get(
      instrumentationName: "APIService"
    )
    let span = tracer.spanBuilder(
      spanName: "API Service: \(method) /\(endpoint)"
    )
    .setActive(true)
    .startSpan()

    defer {
      span.end()
    }

    guard var urlComponents = URLComponents(string: "\(baseUrl)/\(endpoint)")
    else {
      span.status = .error(description: "Bad URL")
      return .error(URLError(.badURL))
    }

    urlComponents.queryItems = queryItems

    guard let url = urlComponents.url else {
      span.status = .error(description: "Bad URL")
      return .error(URLError(.badURL))
    }

    span.setAttribute(key: "http.method", value: method)
    span.setAttribute(key: "http.url", value: url.absoluteString)
    span.setAttribute(key: "http.target", value: endpoint)

    print("REQUEST: \(method) \(url)")
    let request = await createRequest(for: url, method: method, body: body)

    do {
      let (data, response) = try await URLSession.shared.data(for: request)

      if let httpResponse = response as? HTTPURLResponse {
        span.setAttribute(
          key: "http.status_code",
          value: httpResponse.statusCode
        )

        if httpResponse.statusCode == 401 {
          span.status = .error(description: "Unauthorized")
          await AuthManager.shared.signOut()
          return .error(
            APIErrorMessage(message: "Session expired. Please sign in again.")
          )
        }
        if httpResponse.statusCode == 503, httpResponse.statusCode == 504 {
          span.status = .error(description: "Service unavailable")
          return .error(
            APIErrorMessage(message: "Service unavailable.")
          )
        }
      }

      let decoder = JSONDecoder()

      decoder.dateDecodingStrategy = .custom { decoder in
        let container = try decoder.singleValueContainer()
        let dateString = try container.decode(String.self)

        let formatter = ISO8601DateFormatter()

        formatter.formatOptions = [
          .withInternetDateTime, .withFractionalSeconds, .withTimeZone,
        ]
        if let date = formatter.date(from: dateString) {
          return date
        }

        formatter.formatOptions = [.withInternetDateTime, .withTimeZone]
        if let date = formatter.date(from: dateString) {
          return date
        }

        throw DecodingError.dataCorrupted(
          DecodingError.Context(
            codingPath: decoder.codingPath,
            debugDescription: "Invalid date format: \(dateString)"
          )
        )
      }

      do {
        let decodedResponse = try decoder.decode(
          RequestResponse<T>.self,
          from: data
        )
        if decodedResponse.success {
          if T.self == EmptyResponse.self {
            span.status = .ok
            return .success(EmptyResponse() as! T)
          }

          guard let responseData = decodedResponse.data else {
            span.status = .error(
              description: "API returned success but no data"
            )
            return .error(
              APIErrorMessage(message: "API returned success but no data")
            )
          }

          span.status = .ok
          return .success(responseData)
        }
        span.status = .error(
          description: decodedResponse.error ?? "Unknown API error"
        )
        return .error(
          APIErrorMessage(message: decodedResponse.error ?? "Unknown API error")
        )
      } catch {
        print("API response decoding error: \(error)")
        span.status = .error(
          description: "Decoding error: \(error.localizedDescription)"
        )
        return .error(error)
      }
    } catch {
      print("API call error: \(error)")
      span.status = .error(
        description: "Request error: \(error.localizedDescription)"
      )
      return .error(error)
    }
  }
}
