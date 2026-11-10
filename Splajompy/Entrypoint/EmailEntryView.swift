import SwiftUI

struct EmailEntryView: View {
  @Binding var viewModel: RegistrationViewModel

  @FocusState private var isFocused: Bool

  var body: some View {
    ScrollView {
      VStack {
        Text("What's your email?")
          .font(SJFont.title)
          .padding()

        TextField("Email", text: $viewModel.email)
          .textContentType(.emailAddress)
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

        if case .invalid(let error) = viewModel.emailValidation {
          Text(error)
            .padding()
            .font(SJFont.body)
            .foregroundStyle(.red.secondary)
            .transition(.opacity)
        }
      }
      .animation(.default, value: viewModel.emailValidation)

      .frame(maxWidth: .infinity, alignment: .leading)
      .padding()
    }
    .pageTitle("Register")
    .safeAreaInset(edge: .bottom) {
      Button {
        Task {
          await viewModel.setEmail()
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
  @Previewable @State var viewModel = RegistrationViewModel()

  NavigationStack {
    EmailEntryView(viewModel: $viewModel)
  }
}
