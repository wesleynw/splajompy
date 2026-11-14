import SwiftUI

struct RegistrationView: View {
  @State private var viewModel = RegistrationViewModel()
  @Environment(\.dismiss) private var dismiss: DismissAction

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
    #if os(macOS)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button {
            dismiss()
          } label: {
            Text("Close")
            .font(SJFont.body)
          }
          .controlSize(.large)
          .modify {
            if #available(anyAppleOS 26, *) {
              $0.buttonStyle(.glass)
            }
          }
        }
      }
    #endif
  }
}
