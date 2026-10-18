import Connect
import Foundation
import OpenTelemetryApi

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
  static let baseUrl: String =
    Bundle.main.object(forInfoDictionaryKey: "API_URL") as? String
    ?? "http://api.splajompy.com"

  static let connectClient = ProtocolClient(
    httpClient: URLSessionHTTPClient(),
    config: ProtocolClientConfig(
      host: baseUrl,
      networkProtocol: .connect,
      codec: ProtoCodec(),
      interceptors: [.init { _ in ConnectAPIInterceptor() }]
    )
  )

  private static func createRequest(
    for url: URL,
    method: String = "GET",
    body: Data? = nil,
    requiresAuth: Bool = true
  ) async throws -> URLRequest {
    var request = URLRequest(url: url)
    request.httpMethod = method

    let token = await AuthManager.shared.getAuthToken()
    if requiresAuth {
      guard let token else {
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

    return request
  }

  static private func executeRequest(
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

    guard var urlComponents = URLComponents(string: "\(baseUrl)/\(endpoint)")
    else {
      span.status = .error(description: "Bad URL")
      return .failure(URLError(.badURL))
    }

    urlComponents.queryItems = queryItems

    guard let url = urlComponents.url else {
      span.status = .error(description: "Bad URL")
      return .failure(URLError(.badURL))
    }

    span.setAttribute(key: "http.method", value: method)
    span.setAttribute(key: "http.url", value: url.absoluteString)
    span.setAttribute(key: "http.target", value: endpoint)

    print("REQUEST: \(method) \(url)")
    let request: URLRequest
    do {
      request = try await createRequest(
        for: url,
        method: method,
        body: body,
        requiresAuth: requiresAuth
      )
    } catch {
      span.status = .error(description: error.localizedDescription)
      return .failure(error)
    }

    do {
      let (data, response) = try await URLSession.shared.data(for: request)

      if let httpResponse = response as? HTTPURLResponse {
        span.setAttribute(
          key: "http.status_code",
          value: httpResponse.statusCode
        )

        if httpResponse.statusCode == 426 {
          await MainActor.run {
            NotificationCenter.default.post(
              name: .userNeedsAppUpgrade,
              object: nil
            )
          }
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
      }
    } catch {
      print("API call error: \(error)")
      span.status = .error(
        description: "Request error: \(error.localizedDescription)"
      )
      return .failure(error)
    }

    return .failure(APIErrorMessage(message: "TODO"))
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

final class ConnectAPIInterceptor: UnaryInterceptor {
  private let tokenProvider: @Sendable () async -> String?
  private let appVersion: String?
  private let onUnauthenticated: @MainActor @Sendable () -> Void
  private let onUpgradeRequired: @MainActor @Sendable () -> Void

  init(
    tokenProvider: @escaping @Sendable () async -> String? = {
      await AuthManager.shared.getAuthToken()
    },
    appVersion: String? = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
    onUnauthenticated: @escaping @MainActor @Sendable () -> Void = {
      AuthManager.shared.signOut(reason: "401_rpc")
    },
    onUpgradeRequired: @escaping @MainActor @Sendable () -> Void = {
      NotificationCenter.default.post(name: .userNeedsAppUpgrade, object: nil)
    }
  ) {
    self.tokenProvider = tokenProvider
    self.appVersion = appVersion
    self.onUnauthenticated = onUnauthenticated
    self.onUpgradeRequired = onUpgradeRequired
  }

  func handleUnaryRequest<Message: ProtobufMessage>(
    _ request: HTTPRequest<Message>,
    proceed: @escaping @Sendable (Result<HTTPRequest<Message>, ConnectError>) -> Void
  ) {
    Task {
      guard let token = await tokenProvider() else {
        proceed(.failure(ConnectError(code: .unauthenticated, message: "Not authenticated")))
        return
      }
      var headers = request.headers
      headers["Authorization"] = ["Bearer \(token)"]
      headers["X-App-Version"] = appVersion.map { [$0] }
      proceed(
        .success(
          HTTPRequest(
            url: request.url,
            headers: headers,
            message: request.message,
            method: request.method,
            trailers: request.trailers,
            idempotencyLevel: request.idempotencyLevel
          )))
    }
  }

  func handleUnaryResponse<Message: ProtobufMessage>(
    _ response: ResponseMessage<Message>,
    proceed: @escaping @Sendable (ResponseMessage<Message>) -> Void
  ) {
    let handleError: @MainActor @Sendable () -> Void
    switch response.error?.code {
    case .unauthenticated:
      handleError = onUnauthenticated
    case .failedPrecondition
    where response.error?.metadata["x-minimum-app-version"]?.first != nil:
      handleError = onUpgradeRequired
    default:
      proceed(response)
      return
    }
    Task { @MainActor in
      handleError()
      proceed(response)
    }
  }
}
