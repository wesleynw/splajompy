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

  var password: String? = nil

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
      self.usernameValidation = .invalid("This doesn't look like a username")
      return
    }

    let usernameError = authService.validateUsername(username)
    if let usernameError {
      self.usernameAvailableCheckTask?.cancel()
      self.usernameValidation = .invalid(usernameError)
      return
    }

    await scheduleUsernameAvailabilityCheck()
  }

  func scheduleUsernameAvailabilityCheck() async {
    // validation isn't done via field check, don't show validation errors to user until clicking "continue"
    guard username.count > 0, authService.validateUsername(self.username) == nil
    else { return }

    usernameAvailableCheckTask?.cancel()
    usernameValidation = .pending

    let candidate = username

    usernameAvailableCheckTask = Task {
      do { try await Task.sleep(for: .seconds(2)) } catch { return }

      let result = await authService.getIsUsernameAvailable(self.username)
      guard !Task.isCancelled, candidate == self.username else { return }

      switch result {
      case .success(_):
        self.usernameValidation = .valid
      case .failure(let failure):
        self.usernameValidation = .invalid(failure.localizedDescription)
      }

      usernameAvailableCheckTask = nil
    }
  }
}
