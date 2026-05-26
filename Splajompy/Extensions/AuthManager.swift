import Foundation
import Nuke
import PostHog
import SwiftUI

struct AuthResponse: Decodable {
  let token: String
  let user: CurrentUserModel
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

@MainActor @Observable
class AuthManager: Sendable {
  var isAuthenticated: Bool = false
  var isLoading: Bool = false

  static let shared = AuthManager()

  init() {
    checkAuthenticationState()
  }

  func checkAuthenticationState() {
    let hasToken = getAuthToken() != nil
    let hasValidUserData = getCurrentUser() != nil

    PostHogSDK.shared.capture(
      "auth_state_check",
      properties: ["has_token": hasToken, "has_user_data": hasValidUserData]
    )

    isAuthenticated = hasToken && hasValidUserData

    if hasToken && !hasValidUserData {
      signOut(reason: "missing_user_data_on_init")
    }
  }

  nonisolated func getAuthToken() -> String? {
    let (tokenData, status) = KeychainHelper.standard.readWithStatus(
      service: "session-token",
      account: "self"
    )

    guard let tokenData else {
      if status != errSecSuccess {
        PostHogSDK.shared.capture(
          "keychain_read_failed",
          properties: ["status": status.description, "item": "session-token"]
        )
      }
      return nil
    }

    guard var tokenString = String(data: tokenData, encoding: .utf8) else {
      return nil
    }

    // migrate tokens saved in old JSON-encoded format (surrounded by quotes).
    if tokenString.hasPrefix("\"") && tokenString.hasSuffix("\"") {
      tokenString = String(tokenString.dropFirst().dropLast())
      if let migrated = tokenString.data(using: .utf8) {
        KeychainHelper.standard.save(
          migrated,
          service: "session-token",
          account: "self"
        )
      }
    }

    return tokenString
  }

  func signOut(reason: String = "manual") {
    PostHogSDK.shared.capture("user_signout", properties: ["reason": reason])
    KeychainHelper.standard.delete(service: "session-token", account: "self")

    // todo: put these in a map so can iterate over them and keep track of them everywhere???
    UserDefaults.standard.removeObject(forKey: "CurrentUserID")
    UserDefaults.standard.removeObject(forKey: "CurrentUserUsername")
    UserDefaults.standard.removeObject(forKey: "CurrentUserEmail")
    UserDefaults.standard.removeObject(forKey: "CurrentUserCreatedAt")
    UserDefaults.standard.removeObject(forKey: "CurrentUserName")
    UserDefaults.standard.removeObject(forKey: "selectedFeedType")
    UserDefaults.standard.removeObject(forKey: "push_notifications_enabled")
    UserDefaults.standard.removeObject(forKey: "push_pref_comments")
    UserDefaults.standard.removeObject(forKey: "push_pref_mentions")
    UserDefaults.standard.removeObject(forKey: "push_pref_follows")
    UserDefaults.standard.removeObject(forKey: "image_layout_preference")

    ImageCache.shared.removeAll()
    ImagePipeline.shared.cache.removeAll()

    NotificationCenter.default.post(name: .userDidSignOut, object: nil)
    RemoteNotificationUtilities.unregisterForRemoteNotifications()

    isAuthenticated = false
  }

  func getCurrentUser() -> CurrentUserModel? {
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
    let createdAt = (try? Date(createdAtString, strategy: .iso8601)) ?? Date()

    return CurrentUserModel(
      userId: userId,
      email: email,
      username: username,
      createdAt: createdAt,
      name: name,
    )
  }

  private func saveUserData(_ user: CurrentUserModel, token: String) {
    if let tokenData = token.data(using: .utf8) {
      KeychainHelper.standard.save(
        tokenData,
        service: "session-token",
        account: "self"
      )
    }

    let defaults = UserDefaults.standard
    defaults.set(user.userId, forKey: "CurrentUserID")
    defaults.set(user.username, forKey: "CurrentUserUsername")
    defaults.set(user.email, forKey: "CurrentUserEmail")

    let createdAtString = user.createdAt.ISO8601Format()
    defaults.set(createdAtString, forKey: "CurrentUserCreatedAt")

    if let name = user.name {
      defaults.set(name, forKey: "CurrentUserName")
    }

    isAuthenticated = true
  }

  /// Request a one time code be sent to the email of the user given by the identifier.
  func requestOneTimeCode(for identifier: String) async -> Bool {
    isLoading = true
    defer { isLoading = false }

    struct Body: Encodable {
      let identifier: String
    }

    guard
      let jsonData = try? JSONEncoder().encode(
        Body(identifier: identifier.lowercased())
      )
    else {
      return false
    }

    let result: AsyncResult<EmptyResponse> = await APIService.performRequest(
      endpoint: "otc/generate",
      method: "POST",
      body: jsonData,
      requiresAuth: false
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
        Body(identifier: identifier.lowercased(), code: code)
      )
    else {
      return false
    }

    let result: AsyncResult<AuthResponse> = await APIService.performRequest(
      endpoint: "otc/verify",
      method: "POST",
      body: jsonData,
      requiresAuth: false
    )

    switch result {
    case .success(let authResponse):
      saveUserData(authResponse.user, token: authResponse.token)
      PostHogSDK.shared.identify(
        String(authResponse.user.userId),
        userProperties: [
          "email": authResponse.user.email,
          "username": authResponse.user.username,
        ]
      )
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
      identifier: identifier.lowercased(),
      password: password
    )

    guard let jsonData = try? JSONEncoder().encode(credentials) else {
      return (false, "Failed to encode credentials")
    }

    let result: AsyncResult<AuthResponse> = await APIService.performRequest(
      endpoint: "login",
      method: "POST",
      body: jsonData,
      requiresAuth: false
    )

    switch result {
    case .success(let authResponse):
      saveUserData(authResponse.user, token: authResponse.token)
      PostHogSDK.shared.identify(
        String(authResponse.user.userId),
        userProperties: [
          "email": authResponse.user.email,
          "username": authResponse.user.username,
        ]
      )
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
      username: username,
      email: email,
      password: password
    ) {
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
      body: requestBody,
      requiresAuth: false
    )

    switch result {
    case .success(let authResponse):
      saveUserData(authResponse.user, token: authResponse.token)
      PostHogSDK.shared.identify(
        String(authResponse.user.userId),
        userProperties: [
          "email": authResponse.user.email,
          "username": authResponse.user.username,
        ]
      )
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

    if username.count < 2 {
      return "Username must be at least 2 character"
    }

    if username.count > 25 {
      return "Username must be 25 characters or less"
    }

    if username.wholeMatch(of: MentionUtilities.usernameRegex) == nil {
      return
        "Username must start and end with a letter or number, and can only contain letters, numbers, periods, and underscores"
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

  private func validateRegistrationInput(
    username: String,
    email: String,
    password: String
  )
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
      signOut(reason: "account_deleted")
      return (true, "")
    case .error(let error):
      return (false, error.localizedDescription)
    }
  }
}

extension Foundation.Notification.Name {
  static let userDidSignOut = Foundation.Notification.Name("userDidSignOut")
}
