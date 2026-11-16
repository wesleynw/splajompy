import SwiftUI

enum FieldState: Equatable {
  case pending
  case valid
  case invalid(String)
  case unchanged
}

enum OnboardingStep {
  case emailVerify
  case usernameEntry
  case passwordEntry
}

@Observable @MainActor
class RegistrationViewModel {
  private let authService: AuthManager = AuthManager.shared

  var path: NavigationPath = NavigationPath()
  var alertText: String?

  var email: String = ""
  var emailVerificationCode: String = ""
  private(set) var emailValidation: FieldState = .unchanged

  private(set) var isSendingVerificationEmail: Bool = false
  private(set) var isVerifyingEmailCode: Bool = false

  var username: String = ""
  private(set) var usernameValidation: FieldState = .unchanged

  var usernameAvailableCheckTask: Task<Void, Never>?

  private var isEmailVerified: Bool = false

  var password: String = ""

  private(set) var passwordValidation: FieldState = .unchanged

  func setEmail() async {
    guard email.count > 1 else {
      self.emailValidation = .invalid("This doesn't look like an email")
      return
    }

    isSendingVerificationEmail = true
    defer {
      isSendingVerificationEmail = false
    }

    let emailError = authService.validateEmail(email)
    if let emailError {
      self.emailValidation = .invalid(emailError)
      return
    }

    self.emailValidation = .valid

    let result = await authService.requestEmailVerification(for: self.email)
    switch result {
    case .success(_):
      path.append(OnboardingStep.emailVerify)
    case .failure(let failure):
      self.emailValidation = .invalid(failure.localizedDescription)
    }
  }

  func requestEmailVerification() async {
    guard emailValidation == .valid, emailVerificationCode.count > 0 else {
      return
    }

    isVerifyingEmailCode = true
    defer {
      isVerifyingEmailCode = false
    }

    let result = await authService.verifyEmail(
      for: self.email,
      with: self.emailVerificationCode
    )
    switch result {
    case .success(_):
      path.append(OnboardingStep.usernameEntry)
    case .failure(let failure):
      alertText = failure.localizedDescription
    }

  }

  func setUsername() async {
    guard username.count > 0 else {
      self.usernameValidation = .unchanged
      return
    }

    usernameAvailableCheckTask?.cancel()
    usernameValidation = .pending

    let candidate = username

    usernameAvailableCheckTask = Task {
      do { try await Task.sleep(for: .seconds(1)) } catch { return }

      let usernameError = authService.validateUsername(candidate)
      if let usernameError {
        self.usernameValidation = .invalid(usernameError)
        return
      }

      let result = await authService.getIsUsernameAvailable(self.username)
      guard !Task.isCancelled, candidate == self.username else { return }

      switch result {
      case .success(_):
        self.usernameValidation = .valid
      case .failure(let failure):
        self.usernameValidation = .invalid(failure.localizedDescription)
      }
    }

  }

  func setPassword() async {
    guard self.password.count > 0 else {
      return
    }

    if let passwordError = self.authService.validatePassword(self.password) {
      self.passwordValidation = .invalid(passwordError)
      return
    }

    // actually register
    let result = await self.authService.register(
      username: self.username,
      email: self.email,
      password: self.password
    )

    switch result {
    case .success(_):
      return
    case .failure(let error):
      self.alertText = error.localizedDescription
    }
  }
}
