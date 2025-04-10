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

class AuthManager: ObservableObject, @unchecked Sendable {
  @Published var isAuthenticated: Bool = false
  @Published var isLoading: Bool = false

  static let shared = AuthManager()

  init() {
    let sessionToken = KeychainHelper.standard.read(
      service: "session-token",
      account: "self"
    )
    isAuthenticated = sessionToken != nil
  }

  func getAuthToken() -> String? {
    guard
      let tokenData = KeychainHelper.standard.read(
        service: "session-token",
        account: "self"
      )
    else {
      return nil
    }

    guard let tokenString = String(data: tokenData, encoding: .utf8) else {
      return nil
    }

    let token = tokenString.trimmingCharacters(
      in: CharacterSet(charactersIn: "\"")
    )

    return token
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

  func signInWithPassword(identifier: String, password: String) async
    -> AuthError
  {
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
      // Convert credentials to JSON data
      let jsonData = try JSONEncoder().encode(credentials)
      
      // Use the new APIService
      let result: APIResult<AuthResponse> = await APIService.performRequest(
        endpoint: "login",
        method: "POST",
        body: jsonData
      )
      
      // Handle the result
      switch result {
      case .success(let authResponse):
        KeychainHelper.standard.save(
          authResponse.token,
          service: "session-token",
          account: "self"
        )

        let defaults = UserDefaults.standard
        defaults.set(authResponse.user.userId, forKey: "CurrentUserID")
        defaults.set(authResponse.user.username, forKey: "CurrentUserUsername")

        await MainActor.run {
          isAuthenticated = true
          isLoading = false
        }

        return .none
        
      case .failure(let error):
        await MainActor.run {
          isLoading = false
        }
        
        if error is URLError {
          return .invalidURL
        } else if error is DecodingError {
          return .decodingError
        } else if let httpResponse = error as? HTTPURLResponse {
          if httpResponse.statusCode == 401 {
            return .incorrectPassword
          } else if httpResponse.statusCode == 404 {
            return .accountNonexistent
          } else {
            return .generalFailure
          }
        } else {
          return .generalFailure
        }
      }
    } catch {
      await MainActor.run {
        isLoading = false
      }
      return .serializationError
    }
  }
}
