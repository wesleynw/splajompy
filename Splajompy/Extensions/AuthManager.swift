//
//  Authentication.swift
//  Splajompy
//
//  Created by Wesley Weisenberger on 3/17/25.
//
import Foundation

struct AuthResponse: Decodable {
  let token: String
  let user: User
}

enum AuthError {
  case none
  case invalidURL
  case serializationError
  case networkError
  case invalidResponse
  case decodingError
  case incorrectPassword
  case accountNonexistent
  case generalFailure
  case noToken
}

@MainActor class AuthManager: ObservableObject {
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

  func getCurrentUser() -> (userId: Int, username: String) {
    let defaults = UserDefaults.standard

    let userId = defaults.integer(forKey: "CurrentUserID")

    guard let username = defaults.string(forKey: "CurrentUserUsername") else {
      signOut()
      return (0, "")
    }

    if userId == 0 {
      signOut()
      return (0, "")
    }

    return (userId, username)
  }

  func signInWithPassword(identifier: String, password: String) async -> AuthError {
    await MainActor.run {
      isLoading = true
    }
    struct LoginCredentials: Encodable {
      let identifier: String
      let password: String
    }

    let credentials = LoginCredentials(
      identifier: identifier,
      password: password
    )

    do {
      let authResponse: AuthResponse = try await APIService.shared.request(
        endpoint: "/login",
        method: "POST",
        body: credentials,
        requiresAuth: false
      )

      KeychainHelper.standard.save(authResponse.token, service: "session-token", account: "self")

      let defaults = UserDefaults.standard
      defaults.set(authResponse.user.userId, forKey: "CurrentUserID")
      defaults.set(authResponse.user.username, forKey: "CurrentUserUsername")

      await MainActor.run {
        isAuthenticated = true
        isLoading = false
      }

      return .none

    } catch let apiError as APIError {
      await MainActor.run {
        isLoading = false
      }
      switch apiError {
      case .invalidURL:
        return .invalidURL
      case .decodingError:
        return .decodingError
      case .unauthorized:
        return .incorrectPassword
      case .serverError(404):
        return .accountNonexistent
      case .noToken:
        return .noToken
      case .networkError, .noData, .serverError:
        return .generalFailure
      }
    } catch {
      await MainActor.run {
        isLoading = false
      }
      return .generalFailure
    }
  }
}
