import SwiftUI

enum FieldState: Equatable {
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

  var username: String? = nil
  var password: String? = nil

  private var isEmailVerified: Bool = false

  func setEmail() async {
    guard email.count > 1 else {
      self.emailValidation = .invalid("This doesn't look like an email")
      return
    }

    let emailError = AuthManager().validateEmail(email)
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
    case .success(let success):
      path.append(OnboardingStep.usernameEntry)
    case .failure(let failure):
      alertText = failure.localizedDescription
    }

  }
}
