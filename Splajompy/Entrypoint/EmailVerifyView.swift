import SwiftUI

struct EmailVerifyView: View {
  @Binding var viewModel: RegistrationViewModel
  @Environment(\.dismiss) private var dismiss

  @FocusState var isFocused

  var body: some View {
    ScrollView {
      VStack {
        Text("Check your email")
          .font(SJFont.title)

        Text("A code has been sent to \(viewModel.email)")
          .font(SJFont.body)
          .padding()
      }
      .padding()

      TextField("Code", text: $viewModel.emailVerificationCode)
        .textContentType(.oneTimeCode)
        .padding()
        .background {
          RoundedRectangle(cornerRadius: 10)
            .stroke()
        }
        #if os(iOS)
          .keyboardType(.numberPad)
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

      if case .invalid(let error) = viewModel.emailCodeValidation {
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
    .pageTitle("Register")
    .padding()
    .toolbar {
      #if os(macOS)
        ToolbarItem(placement: .confirmationAction) {
          continueButton
        }
      #endif
    }
    #if os(iOS)
      .safeAreaInset(edge: .bottom) {
        continueButton
        .padding()
      }
    #endif
  }

  @ContentBuilder
  var continueButton: some View {
    AsyncActionButton(
      title: "Continue",
      isLoading: viewModel.isVerifyingEmailCode,
      isDisabled: viewModel.emailVerificationCode.count == 0
    ) {
      await viewModel.setEmailVerificationCode()
    }
  }
}

#Preview {
  @Previewable @State var viewModel: RegistrationViewModel =
    RegistrationViewModel()
  viewModel.email = "wesleynw@pm.me"

  return EmailVerifyView(viewModel: $viewModel)
}
