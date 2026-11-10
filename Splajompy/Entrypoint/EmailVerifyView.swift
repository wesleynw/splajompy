import SwiftUI

struct EmailVerifyView: View {
  @Binding var viewModel: RegistrationViewModel

  @FocusState var isFocused

  var body: some View {
    ScrollView {
      VStack {
        Text("Check your email")
          .font(SJFont.title)

        Text("A code has been sent to ")
          + Text("\(viewModel.email)").fontWeight(.bold)
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
    }
    .padding()
    .onAppear {
      isFocused = true
    }
    .safeAreaInset(edge: .bottom) {
      Button {
        Task {
          await viewModel.requestEmailVerification()
        }
      } label: {
        Text("Continue")
          .font(SJFont.body)
          .frame(maxWidth: .infinity)
      }
      .disabled(viewModel.email.count == 0)
      .controlSize(.extraLarge)
      .modify {
        if #available(anyAppleOS 26, *) {
          $0.buttonStyle(.glassProminent)
        } else {
          $0.buttonStyle(.borderedProminent)
        }
      }
      .padding()
    }
  }
}

#Preview {
  @Previewable @State var viewModel: RegistrationViewModel =
    RegistrationViewModel()
  viewModel.email = "wesleynw@pm.me"

  return EmailVerifyView(viewModel: $viewModel)
}
