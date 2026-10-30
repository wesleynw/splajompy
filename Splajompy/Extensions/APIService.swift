import Foundation
import OpenTelemetryApi
import os

public struct RequestResponse<T: Decodable & Sendable>: Decodable, Sendable {
  let success: Bool
  let data: T?
  let error: String?
}

public struct APIErrorMessage: Error, LocalizedError {
  let message: String

  public var errorDescription: String? {
    return message
  }
}

extension Foundation.Notification.Name {
  static let userNeedsAppUpgrade = Foundation.Notification.Name(
    "user_needs_app_upgrade"
  )
}

public struct APIService {
  static private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier!,
    category: "api"
  )

  static let serverURLKey: String = "api_server_url"

  static let defaultBaseUrl: String =
    Bundle.main.object(forInfoDictionaryKey: "API_URL") as? String
    ?? "https://api.splajompy.com"

  static var baseUrl: String {
    UserDefaults.standard.string(forKey: serverURLKey) ?? defaultBaseUrl
  }

  @MainActor
  private static func createRequest(
    endpoint: String,
    method: String = "GET",
    queryItems: [URLQueryItem]? = nil,
    body: Data? = nil,
    requiresAuth: Bool = true
  ) async throws -> (request: URLRequest, baseUrl: String) {
    let baseUrl = Self.baseUrl
    guard var components = URLComponents(string: "\(baseUrl)/\(endpoint)")
    else {
      throw URLError(.badURL)
    }
    components.queryItems = queryItems
    guard let url = components.url else { throw URLError(.badURL) }

    var request = URLRequest(url: url)
    request.httpMethod = method

    if requiresAuth {
      guard let token = await AuthManager.shared.getAuthToken() else {
        throw APIErrorMessage(message: "Not authenticated")
      }
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

    guard baseUrl == Self.baseUrl else { throw URLError(.cancelled) }
    return (request, baseUrl)
  }

  @MainActor
  private static func executeRequest(
    endpoint: String,
    method: String = "GET",
    queryItems: [URLQueryItem]? = nil,
    body: Data? = nil,
    requiresAuth: Bool = true
  ) async -> Result<(Data, URLResponse), Error> {
    let tracer = OpenTelemetry.instance.tracerProvider.get(
      instrumentationName: "APIService"
    )
    let span = tracer.spanBuilder(
      spanName: "API Service: \(method) /\(endpoint)"
    )
    .setSpanKind(spanKind: .client)
    .startSpan()

    defer {
      span.end()
    }

    span.setAttribute(key: "http.method", value: method)
    span.setAttribute(key: "http.target", value: endpoint)

    do {
      let (request, requestBaseUrl) = try await createRequest(
        endpoint: endpoint,
        method: method,
        queryItems: queryItems,
        body: body,
        requiresAuth: requiresAuth
      )
      if let url = request.url {
        span.setAttribute(key: "http.url", value: url.absoluteString)
        let name = "\(method) \(url)"
        print("REQUEST: \(name)")
        logger.info(
          "Processing API request to endpoint \(name, privacy: .public)"
        )
      }

      let (data, response) = try await URLSession.shared.data(for: request)
      guard requestBaseUrl == Self.baseUrl else {
        return .failure(URLError(.cancelled))
      }
      guard let httpResponse = response as? HTTPURLResponse else {
        throw URLError(.badServerResponse)
      }

      span.setAttribute(
        key: "http.status_code",
        value: httpResponse.statusCode
      )

      if httpResponse.statusCode == 426 {
        NotificationCenter.default.post(
          name: .userNeedsAppUpgrade,
          object: nil
        )
      }

      if httpResponse.statusCode == 401 {
        span.status = .error(description: "Unauthorized")
        await AuthManager.shared.signOut(reason: "401_\(endpoint)")
        return .failure(
          APIErrorMessage(message: "Session expired. Please sign in again.")
        )
      }
      if httpResponse.statusCode == 503 || httpResponse.statusCode == 504 {
        span.status = .error(description: "Service unavailable")
        return .failure(
          APIErrorMessage(message: "Service unavailable.")
        )
      }

      if 500...599 ~= httpResponse.statusCode {
        span.status = .error(description: "internal server error")
        return .failure(APIErrorMessage(message: "Internal Server Error"))
      }

      return .success((data, response))
    } catch {
      print("API call error: \(error)")
      span.status = .error(
        description: "Request error: \(error.localizedDescription)"
      )
      return .failure(error)
    }
  }

  static func performRequest(
    endpoint: String,
    method: String = "GET",
    queryItems: [URLQueryItem]? = nil,
    body: Data? = nil,
    requiresAuth: Bool = true
  ) async -> Result<Void, Error> {
    let requestReponse = await executeRequest(
      endpoint: endpoint,
      method: method,
      queryItems: queryItems,
      body: body,
      requiresAuth: requiresAuth
    )

    switch requestReponse {
    case .success(_):
      return .success(())
    case .failure(let failure):
      return .failure(failure)
    }
  }

  static func performRequest<T: Decodable & Sendable>(
    endpoint: String,
    method: String = "GET",
    queryItems: [URLQueryItem]? = nil,
    body: Data? = nil,
    requiresAuth: Bool = true
  ) async -> Result<T, Error> {
    let requestReponse = await executeRequest(
      endpoint: endpoint,
      method: method,
      queryItems: queryItems,
      body: body,
      requiresAuth: requiresAuth
    )

    switch requestReponse {
    case .success((let data, _)):
      let tracer = OpenTelemetry.instance.tracerProvider.get(
        instrumentationName: "APIService"
      )
      let span = tracer.spanBuilder(spanName: "API Decode: \(endpoint)")
        .setSpanKind(spanKind: .client)
        .startSpan()
      defer { span.end() }

      let decoder = JSONDecoder()

      decoder.dateDecodingStrategy = .custom { decoder in
        let container = try decoder.singleValueContainer()
        let dateString = try container.decode(String.self)

        if let date = try? Date(
          dateString,
          strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        ) {
          return date
        }

        if let date = try? Date(dateString, strategy: .iso8601) {
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
          guard let responseData = decodedResponse.data else {
            span.status = .error(description: "Success response missing data")
            return .failure(
              APIErrorMessage(message: "API returned success but no data")
            )
          }

          return .success(responseData)
        }
        let errorMessage = decodedResponse.error ?? "Unknown API error"
        span.status = .error(description: errorMessage)
        return .failure(
          APIErrorMessage(message: decodedResponse.error ?? "Unknown API error")
        )
      } catch {
        span.status = .error(
          description: "Decoding error: \(error.localizedDescription)"
        )
        print("API response decoding error: \(error)")
        return .failure(error)
      }
    case .failure(let failure):
      return .failure(failure)
    }
  }
}
