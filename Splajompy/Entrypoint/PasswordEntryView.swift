import SwiftUI

struct PasswordEntryView: View {
  @Binding var viewModel: RegistrationViewModel
  @Environment(\.dismiss) private var dismiss
  @FocusState var isFocused

  var body: some View {
    ScrollView {
      VStack {
        Text("Set a password")
          .font(SJFont.heading)
          .padding()

        SecureField("Password", text: $viewModel.password)
          .textContentType(.newPassword)
          .padding()
          .background {
            RoundedRectangle(cornerRadius: 10)
              .stroke()
          }
          #if os(iOS)
            .textInputAutocapitalization(.none)
            .autocapitalization(.none)
            .autocorrectionDisabled()
          #else
            .textFieldStyle(.plain)
          #endif
          .focused($isFocused)
          .onAppear {
            isFocused = true
          }

        if case .invalid(let error) = viewModel.passwordValidation {
          HStack {
            Image(systemName: "exclamationmark.triangle")
            Text(error)
              .font(SJFont.body)
          }
          .padding()
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(.red.tertiary, in: RoundedRectangle(cornerRadius: 35))
        }
      }
      .padding()
    }
    .pageTitle("Register")
    .toolbar {
      #if os(macOS)
        ToolbarItem(placement: .confirmationAction) {
          AsyncActionButton(
            title: "Register",
            isLoading: viewModel.isRegisteringAccount,
            isDisabled: viewModel.password.count < 1
          ) {
            await viewModel.setPassword()
          }
        }
      #endif
    }
    #if os(iOS)
      .safeAreaInset(edge: .bottom) {
        AsyncActionButton(
          title: "Register",
          isLoading: viewModel.isRegisteringAccount,
          isDisabled: viewModel.password.count < 1
        ) {
          await viewModel.setPassword()
        }
      }
    #endif
  }
}

#Preview {
  @Previewable @State var viewModel: RegistrationViewModel =
    RegistrationViewModel()

  PasswordEntryView(viewModel: $viewModel)
}
