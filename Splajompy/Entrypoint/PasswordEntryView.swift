import SwiftUI

struct PasswordEntryView: View {
  @Binding var viewModel: RegistrationViewModel

  @FocusState var isFocused

  var body: some View {
    ScrollView {
      VStack {
        TextField("Password", text: $viewModel.password)
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
      }
    }
  }
}

#Preview {
  @Previewable @State var viewModel: RegistrationViewModel =
    RegistrationViewModel()

  PasswordEntryView(viewModel: $viewModel)
}
