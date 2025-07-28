import Foundation
import Kingfisher
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
    checkAuthenticationState()
  }

  private func checkAuthenticationState() {
    let hasToken = getAuthToken() != nil
    let hasValidUserData = getCurrentUser() != nil

    isAuthenticated = hasToken && hasValidUserData

    if hasToken && !hasValidUserData {
      signOut()
    }
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

    return tokenString.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
  }

  func signOut() {
    #if !DEBUG
      PostHogSDK.shared.reset()
    #endif

    KeychainHelper.standard.delete(service: "session-token", account: "self")

    UserDefaults.standard.removeObject(forKey: "CurrentUserID")
    UserDefaults.standard.removeObject(forKey: "CurrentUserUsername")
    UserDefaults.standard.removeObject(forKey: "CurrentUserEmail")
    UserDefaults.standard.removeObject(forKey: "CurrentUserCreatedAt")
    UserDefaults.standard.removeObject(forKey: "CurrentUserName")

    UserDefaults.standard.removeObject(forKey: "mindlessMode")
    UserDefaults.standard.removeObject(forKey: "selectedFeedType")

    KingfisherManager.shared.cache.clearMemoryCache()
    KingfisherManager.shared.cache.clearDiskCache()

    NotificationCenter.default.post(name: .userDidSignOut, object: nil)

    isAuthenticated = false
  }

  func getCurrentUser() -> User? {
    let defaults = UserDefaults.standard

    guard let userId = defaults.object(forKey: "CurrentUserID") as? Int,
      let username = defaults.string(forKey: "CurrentUserUsername"),
      let email = defaults.string(forKey: "CurrentUserEmail"),
      let createdAtString = defaults.string(forKey: "CurrentUserCreatedAt"),
      !username.isEmpty
    else {
      return nil
    }

    let name = defaults.string(forKey: "CurrentUserName")

    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [
      .withInternetDateTime, .withFractionalSeconds, .withTimeZone,
    ]
    let createdAt = formatter.date(from: createdAtString) ?? Date()

    return User(
      userId: userId,
      email: email,
      username: username,
      createdAt: createdAt,
      name: name
    )
  }

  private func saveUserData(_ user: User, token: String) {
    KeychainHelper.standard.save(
      token,
      service: "session-token",
      account: "self"
    )

    let defaults = UserDefaults.standard
    defaults.set(user.userId, forKey: "CurrentUserID")
    defaults.set(user.username, forKey: "CurrentUserUsername")
    defaults.set(user.email, forKey: "CurrentUserEmail")

    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [
      .withInternetDateTime, .withFractionalSeconds, .withTimeZone,
    ]
    let createdAtString = formatter.string(from: user.createdAt)
    defaults.set(createdAtString, forKey: "CurrentUserCreatedAt")

    if let name = user.name {
      defaults.set(name, forKey: "CurrentUserName")
    }

    isAuthenticated = true
  }

  func requestOneTimeCode(for identifier: String) async -> Bool {
    isLoading = true
    defer { isLoading = false }

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

    switch result {
    case .success:
      return true
    case .error:
      return false
    }
  }

  func verifyOneTimeCode(for identifier: String, code: String) async -> Bool {
    isLoading = true
    defer { isLoading = false }

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
      saveUserData(authResponse.user, token: authResponse.token)
      #if !DEBUG
        PostHogSDK.shared.identify(
          String(authResponse.user.userId),
          userProperties: [
            "email": authResponse.user.email,
            "username": authResponse.user.username,
          ]
        )
      #endif
      PostHogSDK.shared.capture("user_signin_otc")
      return true
    case .error:
      return false
    }
  }

  func signInWithPassword(identifier: String, password: String) async -> (
    success: Bool, error: String
  ) {
    isLoading = true
    defer { isLoading = false }

    struct LoginCredentials: Encodable {
      let identifier: String
      let password: String
    }

    let credentials = LoginCredentials(
      identifier: identifier,
      password: password
    )

    guard let jsonData = try? JSONEncoder().encode(credentials) else {
      return (false, "Failed to encode credentials")
    }

    let result: AsyncResult<AuthResponse> = await APIService.performRequest(
      endpoint: "login",
      method: "POST",
      body: jsonData
    )

    switch result {
    case .success(let authResponse):
      saveUserData(authResponse.user, token: authResponse.token)
      #if !DEBUG
        PostHogSDK.shared.identify(
          String(authResponse.user.userId),
          userProperties: [
            "email": authResponse.user.email,
            "username": authResponse.user.username,
          ]
        )
      #endif
      PostHogSDK.shared.capture("user_signin")
      return (true, "")
    case .error(let error):
      return (false, error.localizedDescription)
    }
  }

  func register(username: String, email: String, password: String) async -> (
    success: Bool, error: String
  ) {
    isLoading = true
    defer { isLoading = false }

    if let validationError = validateRegistrationInput(
      username: username, email: email, password: password)
    {
      return (false, validationError)
    }

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
      saveUserData(authResponse.user, token: authResponse.token)
      #if !DEBUG
        PostHogSDK.shared.identify(
          String(authResponse.user.userId),
          userProperties: [
            "email": authResponse.user.email,
            "username": authResponse.user.username,
          ]
        )
      #endif
      PostHogSDK.shared.capture("user_register")
      return (true, "")
    case .error(let error):
      return (false, error.localizedDescription)
    }
  }

  func validateUsername(_ username: String) -> String? {
    if username.isEmpty {
      return "Username cannot be empty"
    }

    if username.count < 3 {
      return "Username must be at least 3 characters"
    }

    let alphanumericRegex = "^[a-zA-Z0-9]+$"
    let alphanumericPred = NSPredicate(format: "SELF MATCHES %@", alphanumericRegex)
    if !alphanumericPred.evaluate(with: username) {
      return "Username can only contain letters and numbers"
    }

    return nil
  }

  func validateEmail(_ email: String) -> String? {
    if email.isEmpty {
      return "Email cannot be empty"
    }

    let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
    let emailPred = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
    if !emailPred.evaluate(with: email) {
      return "Please enter a valid email address"
    }

    return nil
  }

  func validatePassword(_ password: String) -> String? {
    if password.isEmpty {
      return "Password cannot be empty"
    }

    if password.count < 8 {
      return "Password must be at least 8 characters"
    }

    return nil
  }

  private func validateRegistrationInput(username: String, email: String, password: String)
    -> String?
  {
    if let usernameError = validateUsername(username) {
      return usernameError
    }

    if let emailError = validateEmail(email) {
      return emailError
    }

    if let passwordError = validatePassword(password) {
      return passwordError
    }

    return nil
  }

  func deleteAccount(password: String) async -> (success: Bool, error: String) {
    isLoading = true
    defer { isLoading = false }

    struct DeleteAccountRequest: Encodable {
      let password: String
    }

    guard
      let jsonData = try? JSONEncoder().encode(
        DeleteAccountRequest(password: password)
      )
    else {
      return (false, "Failed to serialize request")
    }

    let result: AsyncResult<EmptyResponse> = await APIService.performRequest(
      endpoint: "account/delete",
      method: "POST",
      body: jsonData
    )

    switch result {
    case .success:
      signOut()
      return (true, "")
    case .error(let error):
      return (false, error.localizedDescription)
    }
  }
}

extension Foundation.Notification.Name {
  static let userDidSignOut = Foundation.Notification.Name("userDidSignOut")
}
