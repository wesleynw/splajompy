//
//  APIService.swift
//  Splajompy
//
//  Created by Wesley Weisenberger on 3/24/25.
//
import Foundation

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

class APIService {
    static let shared = APIService()
    
//    let apiURL = "https://api.splajompy.com"
    let apiURL = "http://192.168.0.37:8080"
    
    private init() {}
    
    /// Makes an API request with optional authentication
    /// - Parameters:
    ///   - endpoint: The endpoint path
    ///   - method: HTTP method (default: GET)
    ///   - body: Optional request body as encodable object
    ///   - requiresAuth: Whether to attach authentication token (default: true)
    /// - Returns: Decoded response of type T
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
        
        print("making request to: ", url)
        
        // 2. Create request
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 3. Add authentication token if required
        if requiresAuth {
            // Get token from keychain
            guard let tokenData = KeychainHelper.standard.read(service: "session-token", account: "self") else {
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
                break // Success
            case 401:
                if requiresAuth {
                    // Only sign out if we attempted authentication
                    // Use notification center instead of direct reference to avoid circular dependency
                    NotificationCenter.default.post(name: Notification.Name("AuthenticationFailure"), object: nil)
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
            
            // 7. Decode response
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
    
    func requestWithoutResponse(
        endpoint: String,
        method: String = "GET",
        requiresAuth: Bool = true
    ) async throws {
        let _: EmptyResponse = try await request(endpoint: endpoint, method: method, requiresAuth: requiresAuth)
    }
}
