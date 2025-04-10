//
//  oldAPIService.swift
//  Splajompy
//
//  Created by Wesley Weisenberger on 3/24/25.
//

import Foundation
import SwiftUI

enum APIError: Error {
  case invalidURL
  case networkError(Error)
  case noData
  case decodingError
  case unauthorized
  case serverError(Int)
  case noToken
}

struct EmptyResponse: Decodable {}

@MainActor class oldAPIService {
  @MainActor static let shared = oldAPIService()

  let apiURL: String

  private init() {
    if let apiUrl = Bundle.main.object(forInfoDictionaryKey: "API_URL") as? String {
      self.apiURL = apiUrl
      print("api url: \(apiUrl)")
    } else {
      print("unable to find API key")
      self.apiURL = "https://api.splajompy.com"  // default
    }
  }

  /// Makes an API request with optional authentication
  /// - Parameters:
  ///   - endpoint: The endpoint path
  ///   - method: HTTP method (default: GET)
  ///   - body: Optional request body as encodable object
  ///   - requiresAuth: Whether to attach authentication token (default: true)
  /// - Returns: Decoded response of type T
  @MainActor
  func request<T: Decodable, U: Encodable>(
    endpoint: String,
    method: String = "GET",
    body: U? = nil as String?,
    requiresAuth: Bool = true
  ) async throws -> T {
    // 1. Create URL
    guard let url = URL(string: apiURL + endpoint) else {
      throw APIError.invalidURL
    }

    print("REQUEST -- \(method): \(url)")

    // 2. Create request
    var request = URLRequest(url: url)
    request.httpMethod = method
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    // 3. Add authentication token if required
    if requiresAuth {
      // Get token from keychain
      guard let tokenData = KeychainHelper.standard.read(service: "session-token", account: "self")
      else {
        throw APIError.noToken
      }

      guard let tokenString = String(data: tokenData, encoding: .utf8) else {
        throw APIError.noToken
      }

      // Remove surrounding quotes if present
      let token = tokenString.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    // 4. Add body if provided
    if let body = body {
      let encoder = JSONEncoder()
      request.httpBody = try encoder.encode(body)
    }

    // 5. Make request
    do {
      let (data, response) = try await URLSession.shared.data(for: request)
      guard let httpResponse = response as? HTTPURLResponse else {
        throw APIError.networkError(NSError(domain: "Invalid response", code: 0))
      }

      // 6. Handle HTTP status codes
      switch httpResponse.statusCode {
      case 200...299:
        break  // Success
      case 401:
        Task {
          AuthManager().signOut()
        }
        throw APIError.unauthorized
      default:
        throw APIError.serverError(httpResponse.statusCode)
      }

      guard !data.isEmpty else {
        if T.self == EmptyResponse.self {
          return EmptyResponse() as! T
        } else {
          throw APIError.noData
        }
      }

      do {
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
      } catch {
        print("Decoding error: \(error)")
        throw APIError.decodingError
      }
    } catch let err {
      print("err: ", err.localizedDescription)
      throw err
    }
  }

  func requestWithoutResponse<U: Encodable>(
    endpoint: String,
    method: String = "GET",
    body: U? = nil as String?,
    requiresAuth: Bool = true
  ) async throws {
    let _: EmptyResponse = try await request(
      endpoint: endpoint, method: method, body: body, requiresAuth: requiresAuth)
  }
}

extension oldAPIService {
  /// Uploads an image using multipart form data
  /// - Parameters:
  ///   - endpoint: The endpoint path
  ///   - image: The UIImage to upload
  ///   - fieldName: Form field name for the image (default: "image")
  ///   - fileName: Name of the file (default: "image.jpg")
  ///   - mimeType: MIME type of the image (default: "image/jpeg")
  ///   - compressionQuality: JPEG compression quality (default: 0.7)
  ///   - parameters: Additional form parameters to include
  ///   - body: Optional request body as encodable object
  ///   - requiresAuth: Whether to attach authentication token (default: true)
  /// - Returns: Decoded response of type T
  @MainActor
  func uploadImage<T: Decodable, U: Encodable>(
    endpoint: String,
    image: UIImage,
    fieldName: String = "image",
    fileName: String = "image.jpg",
    mimeType: String = "image/jpeg",
    compressionQuality: CGFloat = 0.7,
    parameters: [String: String]? = nil,
    body: U? = nil as String?,
    requiresAuth: Bool = true
  ) async throws -> T {
    // 1. Create URL
    guard let url = URL(string: apiURL + endpoint) else {
      throw APIError.invalidURL
    }
    print("UPLOAD IMAGE -- POST: \(url)")

    // 2. Create request
    var request = URLRequest(url: url)
    request.httpMethod = "POST"

    // 3. Add authentication token if required
    if requiresAuth {
      guard let tokenData = KeychainHelper.standard.read(service: "session-token", account: "self")
      else {
        throw APIError.noToken
      }
      guard let tokenString = String(data: tokenData, encoding: .utf8) else {
        throw APIError.noToken
      }
      // Remove surrounding quotes if present
      let token = tokenString.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    // 4. Generate boundary string
    let boundary = "Boundary-\(UUID().uuidString)"
    request.setValue(
      "multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

    // 5. Create multipart form data
    var bodyData = Data()

    // 6. Add parameters if provided
    if let parameters = parameters {
      for (key, value) in parameters {
        bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
        bodyData.append(
          "Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
        bodyData.append("\(value)\r\n".data(using: .utf8)!)
      }
    }

    // 6b. Add JSON body if provided
    if let body = body {
      bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
      bodyData.append("Content-Disposition: form-data; name=\"json\"\r\n".data(using: .utf8)!)
      bodyData.append("Content-Type: application/json\r\n\r\n".data(using: .utf8)!)

      let encoder = JSONEncoder()
      let jsonData = try encoder.encode(body)

      if let jsonString = String(data: jsonData, encoding: .utf8) {
        bodyData.append(jsonString.data(using: .utf8)!)
      } else {
        bodyData.append(jsonData)
      }

      bodyData.append("\r\n".data(using: .utf8)!)
    }

    bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
    bodyData.append(
      "Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(
        using: .utf8)!)
    bodyData.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)

    guard let imageData = image.jpegData(compressionQuality: compressionQuality) else {
      throw APIError.networkError(NSError(domain: "Invalid image data", code: 0))
    }

    bodyData.append(imageData)
    bodyData.append("\r\n".data(using: .utf8)!)

    bodyData.append("--\(boundary)--\r\n".data(using: .utf8)!)

    request.httpBody = bodyData

    do {
      let (data, response) = try await URLSession.shared.data(for: request)
      guard let httpResponse = response as? HTTPURLResponse else {
        throw APIError.networkError(NSError(domain: "Invalid response", code: 0))
      }

      // 12. Handle HTTP status codes
      switch httpResponse.statusCode {
      case 200...299:
        break  // Success
      case 401:
        Task {
          AuthManager().signOut()
        }
        throw APIError.unauthorized
      default:
        throw APIError.serverError(httpResponse.statusCode)
      }

      guard !data.isEmpty else {
        if T.self == EmptyResponse.self {
          return EmptyResponse() as! T
        } else {
          throw APIError.noData
        }
      }

      do {
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
      } catch {
        print("Decoding error: \(error)")
        throw APIError.decodingError
      }
    } catch let err {
      print("err: ", err.localizedDescription)
      throw err
    }
  }

  /// Uploads an image using multipart form data with no expected response
  /// - Parameters:
  ///   - endpoint: The endpoint path
  ///   - image: The UIImage to upload
  ///   - fieldName: Form field name for the image (default: "image")
  ///   - fileName: Name of the file (default: "image.jpg")
  ///   - mimeType: MIME type of the image (default: "image/jpeg")
  ///   - compressionQuality: JPEG compression quality (default: 0.7)
  ///   - parameters: Additional form parameters to include
  ///   - body: Optional request body as encodable object
  ///   - requiresAuth: Whether to attach authentication token (default: true)
  @MainActor
  func uploadImageWithoutResponse<U: Encodable>(
    endpoint: String,
    image: UIImage,
    fieldName: String = "image",
    fileName: String = "image.jpg",
    mimeType: String = "image/jpeg",
    compressionQuality: CGFloat = 0.7,
    parameters: [String: String]? = nil,
    body: U? = nil as String?,
    requiresAuth: Bool = true
  ) async throws {
    let _: EmptyResponse = try await uploadImage(
      endpoint: endpoint,
      image: image,
      fieldName: fieldName,
      fileName: fileName,
      mimeType: mimeType,
      compressionQuality: compressionQuality,
      parameters: parameters,
      body: body,
      requiresAuth: requiresAuth)
  }
}
