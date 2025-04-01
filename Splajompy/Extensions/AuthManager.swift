//
//  Authentication.swift
//  Splajompy
//
//  Created by Wesley Weisenberger on 3/17/25.
//
import Foundation

struct AuthResponse: Decodable {
  let Token: String
  let User: User
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
  @Published var isLoading: Bool = false

  init() {
    let sessionToken = KeychainHelper.standard.read(service: "session-token", account: "self")
    isAuthenticated = sessionToken != nil
  }

  func signOut() {
    KeychainHelper.standard.delete(service: "session-token", account: "self")

    Task { @MainActor in
      isAuthenticated = false
    }
  }

  func getCurrentUser() -> Int? {
    let defaults = UserDefaults.standard

    return defaults.integer(forKey: "CurrentUserID")
  }

  func signInWithPassword(identifier: String, password: String) async -> AuthError {
    await MainActor.run {
      isLoading = true
    }
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
        endpoint: "/login",
        method: "POST",
        body: credentials,
        requiresAuth: false
      )

      KeychainHelper.standard.save(authResponse.Token, service: "session-token", account: "self")

      let defaults = UserDefaults.standard
      defaults.set(authResponse.User.UserID, forKey: "CurrentUserID")

      await MainActor.run {
        isAuthenticated = true
        isLoading = false
      }

      return .None

    } catch let apiError as APIError {
      await MainActor.run {
        isLoading = false
      }
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
      await MainActor.run {
        isLoading = false
      }
      return .GeneralFailure
    }
  }
}
