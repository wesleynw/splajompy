//
//  Authentication.swift
//  Splajompy
//
//  Created by Wesley Weisenberger on 3/17/25.
//
import Foundation

struct AuthResponse: Codable {
    let token: String
}

enum AuthError {
    case None
    case InvalidUrl
    case SerializationError
    case NetworkError
    case InvalidResponse
    case DecodingError
    case IncorrectPassword
    case AccountNonexistent
    case GeneralFailure
    case NoToken
}

class AuthManager: ObservableObject {
    @Published var isAuthenticated: Bool = false
    // Don't access the shared instance directly during initialization to avoid dependency cycle
    
    init() {
        let sessionToken = KeychainHelper.standard.read(service: "session-token", account: "self")
        isAuthenticated = sessionToken != nil
    }
    
    func signOut() {
        KeychainHelper.standard.delete(service: "session-token", account: "self")
        isAuthenticated = false
    }
    
    func signInWithPassword(identifier: String, password: String) async -> AuthError {
        let endpoint = "/login"
        
        struct LoginCredentials: Encodable {
            let Identifier: String
            let Password: String
        }
        
        let credentials = LoginCredentials(
            Identifier: identifier,
            Password: password
        )
        
        do {
            let authResponse: AuthResponse = try await APIService.shared.request(
                endpoint: endpoint,
                method: "POST",
                body: credentials,
                requiresAuth: false
            )
            
            KeychainHelper.standard.save(authResponse.token, service: "session-token", account: "self")
            
            await MainActor.run {
                isAuthenticated = true
            }
            
            return .None
            
        } catch let apiError as APIError {
            switch apiError {
            case .invalidURL:
                return .InvalidUrl
            case .decodingError:
                return .DecodingError
            case .unauthorized:
                return .IncorrectPassword
            case .serverError(404):
                return .AccountNonexistent
            case .noToken:
                return .NoToken
            case .networkError, .noData, .serverError:
                return .GeneralFailure
            }
        } catch {
            return .GeneralFailure
        }
    }
}
