import SwiftUI

struct EmailEntryView: View {
  @Binding var viewModel: RegistrationViewModel

  var dismiss: DismissAction

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
          .onAppear {
            isFocused = true
          }

        if case .invalid(let error) = viewModel.emailValidation {
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
      .animation(.default, value: viewModel.emailValidation)

      .frame(maxWidth: .infinity, alignment: .leading)
      .padding()
    }
    .toolbar {
      #if os(macOS)
        ToolbarItem(placement: .confirmationAction) {
          continueButton
        }
      #endif

      ToolbarItem(placement: .cancellationAction) {
        CloseButton(dismiss: dismiss)
      }
    }
    .pageTitle("Register")
    #if os(iOS)
      .safeAreaInset(edge: .bottom) {
        continueButton
        .padding()
      }
    #endif
  }

  @ContentBuilder
  private var continueButton: some View {
    AsyncActionButton(
      title: "Continue",
      isLoading: viewModel.isSendingVerificationEmail,
      isDisabled: viewModel.email.count == 0
    ) {
      await viewModel.setEmail()
    }
  }
}

#Preview {
  @Previewable @State var viewModel = RegistrationViewModel()
  @Previewable @Environment(\.dismiss) var dismiss: DismissAction

  NavigationStack {
    EmailEntryView(viewModel: $viewModel, dismiss: dismiss)
  }
}
