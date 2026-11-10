import SwiftUI

struct RegistrationView: View {
  @State private var viewModel = RegistrationViewModel()

  var body: some View {
    NavigationStack(path: $viewModel.path) {
      EmailEntryView(viewModel: $viewModel)
        .navigationDestination(for: OnboardingStep.self) { route in
          switch route {
          case .emailVerify:
            EmailVerifyView(viewModel: $viewModel)
          case .usernameEntry:
            UsernameEntryView(viewModel: $viewModel)
          }
        }
    }
    .alert(
      "Oops!",
      item: $viewModel.alertText,
      actions: { _ in Button("OK") {} },
      message: { errorStr in
        Text(errorStr)
      }
    )
  }
}
