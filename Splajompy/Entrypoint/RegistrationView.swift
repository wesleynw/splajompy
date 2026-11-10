import SwiftUI

struct RegistrationView: View {
  @State private var viewModel = RegistrationViewModel()
  @Environment(\.dismiss) private var dismiss

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
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            if #available(anyAppleOS 26, *) {
              Button(role: .cancel) {
                dismiss()
              }
            } else {
              Button("Cancel") {
                dismiss()
              }
            }
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
