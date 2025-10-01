import Foundation

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

  static func createRequest(
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
      forHTTPHeaderField: "X-App-Version")

    return request
  }

  static func performRequest<T: Decodable & Sendable>(
    endpoint: String,
    method: String = "GET",
    queryItems: [URLQueryItem]? = nil,
    body: Data? = nil
  ) async -> AsyncResult<T> {
    guard var urlComponents = URLComponents(string: "\(baseUrl)/\(endpoint)")
    else {
      return .error(URLError(.badURL))
    }

    urlComponents.queryItems = queryItems

    guard let url = urlComponents.url else {
      return .error(URLError(.badURL))
    }

    print("REQUEST: \(method) \(url)")
    let request = await createRequest(for: url, method: method, body: body)

    do {
      let (data, response) = try await URLSession.shared.data(for: request)

      if let httpResponse = response as? HTTPURLResponse {
        if httpResponse.statusCode == 401 {
          await AuthManager.shared.signOut()
          return .error(APIErrorMessage(message: "Session expired. Please sign in again."))
        }
      }

      let decoder = JSONDecoder()

      decoder.dateDecodingStrategy = .custom { decoder in
        let container = try decoder.singleValueContainer()
        let dateString = try container.decode(String.self)

        let formatter = ISO8601DateFormatter()

        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withTimeZone]
        if let date = formatter.date(from: dateString) {
          return date
        }

        formatter.formatOptions = [.withInternetDateTime, .withTimeZone]
        if let date = formatter.date(from: dateString) {
          return date
        }

        throw DecodingError.dataCorrupted(
          DecodingError.Context(
            codingPath: decoder.codingPath, debugDescription: "Invalid date format: \(dateString)")
        )
      }

      do {
        let decodedResponse = try decoder.decode(
          RequestResponse<T>.self,
          from: data
        )
        if decodedResponse.success {
          if T.self == EmptyResponse.self {
            return .success(EmptyResponse() as! T)
          }

          guard let responseData = decodedResponse.data else {
            return .error(
              APIErrorMessage(message: "API returned success but no data")
            )
          }

          return .success(responseData)
        }
        return .error(
          APIErrorMessage(message: decodedResponse.error ?? "Unknown API error")
        )
      } catch {
        print("API response decoding error: \(error)")
        return .error(error)
      }
    } catch {
      print("API call error: \(error)")
      return .error(error)
    }
  }
}
