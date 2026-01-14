import SwiftUI

struct OneTimeCodeView: View {
  var identifier: String
  @Environment(\.dismiss) var dismiss
  @FocusState private var isFocused: Bool
  @State private var showError: Bool = false

  @State private var oneTimeCode: String = ""
  @Environment(AuthManager.self) private var authManager

  var body: some View {
    VStack(alignment: .leading) {
      Text("You should receive a verification email momentarily.")
        .font(.body)
        .fontWeight(.bold)
        .foregroundColor(.secondary)
        .padding(.bottom, 20)

      TextField("Code", text: $oneTimeCode)
        .padding(12)
        .background(
          RoundedRectangle(cornerRadius: 8)
            .stroke(
              isFocused ? Color.primary : Color.gray.opacity(0.75),
              lineWidth: 2
            )
        )
        .cornerRadius(8)
        .textContentType(.username)
        .autocorrectionDisabled()
        .focused($isFocused)
        .textContentType(.oneTimeCode)
        #if os(iOS)
          .keyboardType(.numberPad)
        #else
          .textFieldStyle(.plain)
        #endif
        .onAppear { isFocused = true }

    }
    .frame(maxHeight: .infinity, alignment: .topLeading)
    .safeAreaInset(edge: .bottom) {
      AsyncActionButton(
        title: "Continue",
        isLoading: authManager.isLoading,
        isDisabled: authManager.isLoading || oneTimeCode.isEmpty
      ) {
        Task {
          let success = await authManager.verifyOneTimeCode(
            for: identifier,
            code: oneTimeCode
          )
          if !success {
            showError = true
          }
        }
      }
    }
    .navigationTitle("Check your email")
    .padding()
    .alert(isPresented: $showError) {
      Alert(
        title: Text("Sign In Failed"),
        message: Text("Incorrect code."),
        dismissButton: .default(Text("OK"))
      )
    }
  }
}

#Preview {

  NavigationStack {
    OneTimeCodeView(identifier: "wesleynw")
      .environment(AuthManager())
  }
}
