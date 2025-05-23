import Foundation
import PostHog

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

@MainActor
class AuthManager: ObservableObject, Sendable {
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

    PostHogSDK.shared.reset()
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

    PostHogSDK.shared.identify(String(userId), userProperties: ["username": username])

    return (userId, username)
  }

  func requestOneTimeCode(for identifier: String) async -> Bool {
    isLoading = true

    struct Body: Encodable {
      let identifier: String
    }

    guard let jsonData = try? JSONEncoder().encode(Body(identifier: identifier))
    else {
      return false
    }

    let result: AsyncResult<EmptyResponse> = await APIService.performRequest(
      endpoint: "otc/generate",
      method: "POST",
      body: jsonData
    )

    isLoading = false

    switch result {
    case .success:
      return true
    default:
      return false
    }
  }

  func verifyOneTimeCode(for identifier: String, code: String) async -> Bool {
    isLoading = true

    struct Body: Encodable {
      let identifier: String
      let code: String
    }

    guard
      let jsonData = try? JSONEncoder().encode(
        Body(identifier: identifier, code: code)
      )
    else {
      return false
    }

    let result: AsyncResult<AuthResponse> = await APIService.performRequest(
      endpoint: "otc/verify",
      method: "POST",
      body: jsonData
    )

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

      isAuthenticated = true
      isLoading = false

      PostHogSDK.shared.identify(
        String(authResponse.user.userId), userProperties: ["email": authResponse.user.email])
      PostHogSDK.shared.capture("user_signin_otc")

      return true
    case .error:
      isLoading = false
      return false
    }
  }

  func signInWithPassword(identifier: String, password: String) async
    -> (success: Bool, error: String)
  {
    isLoading = true

    struct LoginCredentials: Encodable {
      let identifier: String
      let password: String
    }

    let credentials = LoginCredentials(
      identifier: identifier,
      password: password
    )

    let jsonData: Data
    do {
      jsonData = try JSONEncoder().encode(credentials)
    } catch {
      return (false, error.localizedDescription)
    }

    let result: AsyncResult<AuthResponse> = await APIService.performRequest(
      endpoint: "login",
      method: "POST",
      body: jsonData
    )

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

      isAuthenticated = true
      isLoading = false

      PostHogSDK.shared.identify(
        String(authResponse.user.userId), userProperties: ["email": authResponse.user.email])
      PostHogSDK.shared.capture("user_signin")

      return (true, "")
    case .error(let error):
      isLoading = false
      return (false, error.localizedDescription)
    }
  }

  func register(username: String, email: String, password: String) async
    -> (success: Bool, error: String)
  {
    isLoading = true

    guard
      let requestBody = try? JSONSerialization.data(withJSONObject: [
        "username": username,
        "email": email,
        "password": password,
      ])
    else {
      return (false, "Failed to serialize JSON")
    }

    let result: AsyncResult<AuthResponse> = await APIService.performRequest(
      endpoint: "register",
      method: "POST",
      body: requestBody
    )

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

      PostHogSDK.shared.identify(
        String(authResponse.user.userId), userProperties: ["email": authResponse.user.email])
      PostHogSDK.shared.capture("user_register")

      isAuthenticated = true
      isLoading = false

      return (true, "")
    case .error(let error):
      isLoading = false
      return (false, error.localizedDescription)
    }
  }
}
