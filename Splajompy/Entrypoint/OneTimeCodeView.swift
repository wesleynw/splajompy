import PostHog
import SwiftUI

struct OneTimeCodeView: View {
  @Environment(\.dismiss) var dismiss
  @Environment(AuthManager.self) private var authManager

  @FocusState private var isFocused: Bool

  var identifier: String

  @State private var showError: Bool = false
  @State private var oneTimeCode: String = ""

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 15) {
        Text("You should receive a verification email momentarily.")
          .font(SJFont.callout)

        TextField("Code", text: $oneTimeCode)
          .textContentType(.oneTimeCode)
          .padding()
          .background {
            RoundedRectangle(cornerRadius: 10)
              .stroke(isFocused ? .primary : .secondary)
          }
          .autocorrectionDisabled()
          .focused($isFocused)
          #if os(iOS)
            .keyboardType(.numberPad)
          #else
            .textFieldStyle(.plain)
          #endif
      }
      .padding()
    }
    .onAppear { isFocused = true }
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
      .padding()
    }
    .pageTitle("Login")
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
