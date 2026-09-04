import Foundation
import Nuke
import PostHog
import SwiftUI

struct AuthResponse: Decodable {
  let token: String
  let user: CurrentUserModel
}

struct AuthSession: Codable {
  let token: String
  let user: CurrentUserModel
}

enum AuthState: Equatable {
  case unknown
  case authenticated
  case unauthenticated
}

private actor SessionStore {
  static let shared = SessionStore()

  private static let sessionKeychainService = "auth-session"
  private static let legacyTokenKeychainService = "session-token"
  private static let legacyUserDefaultsKey = "CurrentUserData"
  private static let legacyUserDefaultsKeys = [
    legacyUserDefaultsKey,
    "CurrentUserID",
    "CurrentUserUsername",
    "CurrentUserEmail",
    "CurrentUserCreatedAt",
    "CurrentUserName",
  ]

  func loadSession() -> AuthSession? {
    if let session = readPersistedSession() {
      return session
    }

    return migrateLegacySession()
  }

  @discardableResult
  func persistSession(_ session: AuthSession) -> Bool {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    guard let data = try? encoder.encode(session) else { return false }
    return KeychainHelper.standard.save(data, service: Self.sessionKeychainService, account: "self")
  }

  func clearSession() {
    KeychainHelper.standard.delete(service: Self.sessionKeychainService, account: "self")
    clearLegacyStorage()
  }

  private func clearLegacyStorage() {
    KeychainHelper.standard.delete(service: Self.legacyTokenKeychainService, account: "self")
    for key in Self.legacyUserDefaultsKeys {
      UserDefaults.standard.removeObject(forKey: key)
    }
  }

  private func readPersistedSession() -> AuthSession? {
    guard
      let data = KeychainHelper.standard.read(service: Self.sessionKeychainService, account: "self")
    else { return nil }

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try? decoder.decode(AuthSession.self, from: data)
  }

  private func migrateLegacySession() -> AuthSession? {
    guard
      let tokenData = KeychainHelper.standard.read(
        service: Self.legacyTokenKeychainService,
        account: "self"
      )
    else {
      return nil
    }

    guard var tokenString = String(data: tokenData, encoding: .utf8) else {
      KeychainHelper.standard.delete(service: Self.legacyTokenKeychainService, account: "self")
      return nil
    }

    // older builds stored the token JSON-encoded (surrounded by quotes).
    if tokenString.hasPrefix("\"") && tokenString.hasSuffix("\"") {
      tokenString = String(tokenString.dropFirst().dropLast())
    }

    guard let user = legacyCurrentUser() else {
      clearLegacyStorage()
      return nil
    }

    let session = AuthSession(token: tokenString, user: user)

    guard persistSession(session) else {
      return session
    }

    clearLegacyStorage()

    return session
  }

  private func legacyCurrentUser() -> CurrentUserModel? {
    let defaults = UserDefaults.standard

    if let data = defaults.data(forKey: Self.legacyUserDefaultsKey) {
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      return try? decoder.decode(CurrentUserModel.self, from: data)
    }

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
}

@MainActor @Observable
class AuthManager: Sendable {
  var authState: AuthState = .unknown
  var isLoading: Bool = false
  private(set) var currentUser: CurrentUserModel?

  var isAuthenticated: Bool {
    authState == .authenticated
  }

  static let shared = AuthManager()

  init() {
    Task {
      await resolveInitialSession()
    }
  }

  private func resolveInitialSession() async {
    guard let session = await SessionStore.shared.loadSession() else {
      authState = .unauthenticated
      return
    }

    currentUser = session.user
    authState = .authenticated
  }

  nonisolated func getAuthToken() async -> String? {
    await SessionStore.shared.loadSession()?.token
  }

  func signOut(reason: String = "manual") {
    PostHogSDK.shared.capture("user_signout", properties: ["reason": reason])
    Task {
      await SessionStore.shared.clearSession()
    }

    UserDefaults.standard.removeObject(forKey: "selectedFeedType")
    UserDefaults.standard.removeObject(forKey: "push_notifications_enabled")
    UserDefaults.standard.removeObject(forKey: "push_pref_comments")
    UserDefaults.standard.removeObject(forKey: "push_pref_mentions")
    UserDefaults.standard.removeObject(forKey: "push_pref_follows")
    UserDefaults.standard.removeObject(forKey: "image_layout_preference")
    UserDefaults.standard.removeObject(forKey: "hasCompletedPushNotificationOnboarding")

    ImageCache.shared.removeAll()
    ImagePipeline.shared.cache.removeAll()

    NotificationCenter.default.post(name: .userDidSignOut, object: nil)
    RemoteNotificationUtilities.unregisterForRemoteNotifications()

    authState = .unauthenticated
    currentUser = nil
  }

  private func saveUserData(_ user: CurrentUserModel, token: String) async {
    await SessionStore.shared.persistSession(AuthSession(token: token, user: user))

    authState = .authenticated
    currentUser = user
  }

  private func completeSignIn(_ authResponse: AuthResponse, event: String) async {
    await saveUserData(authResponse.user, token: authResponse.token)
    PostHogSDK.shared.identify(
      String(authResponse.user.userId),
      userProperties: [
        "email": authResponse.user.email,
        "username": authResponse.user.username,
      ]
    )
    PostHogSDK.shared.capture(event)
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

    let result: Result<Void, Error> = await APIService.performRequest(
      endpoint: "otc/generate",
      method: "POST",
      body: jsonData,
      requiresAuth: false
    )

    switch result {
    case .success:
      return true
    case .failure:
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

    let result: Result<AuthResponse, Error> = await APIService.performRequest(
      endpoint: "otc/verify",
      method: "POST",
      body: jsonData,
      requiresAuth: false
    )

    switch result {
    case .success(let authResponse):
      await completeSignIn(authResponse, event: "user_signin_otc")
      return true
    case .failure:
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

    let result: Result<AuthResponse, Error> = await APIService.performRequest(
      endpoint: "login",
      method: "POST",
      body: jsonData,
      requiresAuth: false
    )

    switch result {
    case .success(let authResponse):
      await completeSignIn(authResponse, event: "user_signin")
      return (true, "")
    case .failure(let error):
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

    let result: Result<AuthResponse, Error> = await APIService.performRequest(
      endpoint: "register",
      method: "POST",
      body: requestBody,
      requiresAuth: false
    )

    switch result {
    case .success(let authResponse):
      await completeSignIn(authResponse, event: "user_register")
      return (true, "")
    case .failure(let error):
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

    let result: Result<Void, Error> = await APIService.performRequest(
      endpoint: "account/delete",
      method: "POST",
      body: jsonData
    )

    switch result {
    case .success:
      signOut(reason: "account_deleted")
      return (true, "")
    case .failure(let error):
      return (false, error.localizedDescription)
    }
  }
}

extension Foundation.Notification.Name {
  static let userDidSignOut = Foundation.Notification.Name("userDidSignOut")
}
