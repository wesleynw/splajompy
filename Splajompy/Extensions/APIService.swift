import Foundation

public enum APIResult<T: Sendable>: Sendable {
  case success(T)
  case failure(Error)
}

public struct APIService {
  static let baseUrl: String =
    Bundle.main.object(forInfoDictionaryKey: "API_URL") as? String
    ?? "http://api.splajompy.com"

  static func createRequest(
    for url: URL,
    method: String = "GET",
    body: Data? = nil
  ) -> URLRequest {
    var request = URLRequest(url: url)
    request.httpMethod = method

    if let token = AuthManager.shared.getAuthToken() {
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    if let body = body {
      request.httpBody = body
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }

    return request
  }

  static func performRequest<T: Decodable & Sendable>(
    endpoint: String,
    method: String = "GET",
    queryItems: [URLQueryItem]? = nil,
    body: Data? = nil
  ) async -> APIResult<T> {
    guard var urlComponents = URLComponents(string: "\(baseUrl)/\(endpoint)")
    else {
      return .failure(URLError(.badURL))
    }

    urlComponents.queryItems = queryItems

    guard let url = urlComponents.url else {
      return .failure(URLError(.badURL))
    }

    let request = createRequest(for: url, method: method, body: body)

    do {
      let (data, _) = try await URLSession.shared.data(for: request)

      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601

      do {
        let decodedData = try decoder.decode(T.self, from: data)
        return .success(decodedData)
      } catch {
        return .failure(error)
      }
    } catch {
      return .failure(error)
    }
  }
}

struct EmptyResponse: Decodable {}
