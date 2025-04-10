import Foundation

public enum APIResult<T: Sendable>: Sendable {
  case success(T)
  case failure(Error)
}

public struct APIService2 {
  static let baseUrl: String =
    Bundle.main.object(forInfoDictionaryKey: "API_URL") as? String
    ?? "http://api.splajompy.com"

  static func createRequest(for url: URL, method: String = "GET") -> URLRequest
  {
    var request = URLRequest(url: url)
    request.httpMethod = method
    if let token = AuthManager.shared.getAuthToken() {
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
    return request
  }

  static func performRequest<T: Decodable & Sendable>(
    endpoint: String,
    method: String = "GET",
    queryItems: [URLQueryItem]? = nil
  ) async -> APIResult<T> {
    guard var urlComponents = URLComponents(string: "\(baseUrl)/\(endpoint)")
    else {
      return .failure(URLError(.badURL))
    }

    urlComponents.queryItems = queryItems

    guard let url = urlComponents.url else {
      return .failure(URLError(.badURL))
    }

    let request = createRequest(for: url, method: method)

    do {
      let (data, response) = try await URLSession.shared.data(for: request)

      // Log the response for debugging
      if let httpResponse = response as? HTTPURLResponse {
        print("HTTP Status: \(httpResponse.statusCode)")
      }

      // Log the raw data received
      if let rawString = String(data: data, encoding: .utf8) {
        print("Raw response: \(rawString.prefix(200))...")  // Print first 200 chars
      }

      // Check if we're actually getting an array
      if T.self == [Notification].self {
        // Make sure the data starts with a [ character for an array
        guard let firstByte = data.first, firstByte == 91 /* ASCII for [ */
        else {
          return .failure(
            NSError(
              domain: "APIService",
              code: 1001,
              userInfo: [
                NSLocalizedDescriptionKey:
                  "Expected array but got different data"
              ]
            )
          )
        }
      }

      let decoder = JSONDecoder()
      // Set date decoding strategy if needed
      decoder.dateDecodingStrategy = .iso8601

      do {
        let decodedData = try decoder.decode(T.self, from: data)
        return .success(decodedData)
      } catch {
        print("Decoding error: \(error)")
        // More detailed error handling
        if let decodingError = error as? DecodingError {
          switch decodingError {
          case .dataCorrupted(let context):
            print("Data corrupted: \(context)")
          case .keyNotFound(let key, let context):
            print("Key not found: \(key), context: \(context)")
          case .typeMismatch(let type, let context):
            print("Type mismatch: \(type), context: \(context)")
          case .valueNotFound(let type, let context):
            print("Value not found: \(type), context: \(context)")
          @unknown default:
            print("Unknown decoding error")
          }
        }
        return .failure(error)
      }
    } catch {
      print("Network error: \(error)")
      return .failure(error)
    }
  }
}
