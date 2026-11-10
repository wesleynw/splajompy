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
  private(set) var emailValidation: FieldState = .unchanged

  var emailVerificationCode: String = ""

  var username: String = ""
  private(set) var usernameValidation: FieldState = .unchanged

  var usernameAvailableCheckTask: Task<Void, Never>?

  var password: String? = nil

  private var isEmailVerified: Bool = false

  func setEmail() async {
    guard email.count > 1 else {
      self.emailValidation = .invalid("This doesn't look like an email")
      return
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
      alertText = failure.localizedDescription
    }
  }

  func requestEmailVerification() async {
    guard emailValidation == .valid, emailVerificationCode.count > 0 else {
      return
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
      self.usernameValidation = .invalid(usernameError)
      return
    }

    self.usernameValidation = .pending

    await scheduleUsernameAvailabilityCheck()
  }

  func scheduleUsernameAvailabilityCheck() async {
    let (_, ) = await usernameAvailableCheckTask?.result

    try? await Task.sleep(for: .seconds(2))

    usernameAvailableCheckTask = Task {
      let result = await authService.getIsUsernameAvailable(self.username)
      switch result {
      case .success(_):
        self.usernameValidation = .valid
      case .failure(let failure):
        self.usernameValidation = .invalid(failure.localizedDescription)
      }
    }
  }
}
