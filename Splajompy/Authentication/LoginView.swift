import SwiftUI

struct LoginView: View {
  @Environment(\.dismiss) var dismiss

  @State private var identifier: String = ""
  @State private var isUsingPassword: Bool = true
  @State private var isShowingOtcVerify: Bool = false
  @State private var password = ""
  @State private var hasRequestedCode: Bool = false

  @State var showError: Bool = false
  @State var errorMessage: String = ""

  @FocusState private var isIdentifierFieldFocused: Bool
  @FocusState private var isPasswordFieldFocused: Bool

  @Environment(AuthManager.self) private var authManager

  var body: some View {
    NavigationStack {
      VStack {
        VStack(alignment: .leading, spacing: 5) {
          TextField("Username or Email", text: $identifier)
            .padding(12)
            .background(
              RoundedRectangle(cornerRadius: 8)
                .stroke(
                  isIdentifierFieldFocused
                    ? Color.primary : Color.gray.opacity(0.75),
                  lineWidth: 2
                )
            )
            .cornerRadius(8)
            .textContentType(.username)
            #if os(iOS)
              .autocorrectionDisabled()
            #else
              .textFieldStyle(.plain)
            #endif
            .focused($isIdentifierFieldFocused)
            .onAppear {
              if identifier.isEmpty {
                isIdentifierFieldFocused = true
              } else {
                isPasswordFieldFocused = true
              }
            }
        }
        .padding(.bottom, 10)

        if isUsingPassword {
          VStack(alignment: .leading) {
            SecureField("Password", text: $password)
              .padding(12)
              .background(
                RoundedRectangle(cornerRadius: 8)
                  .stroke(
                    isPasswordFieldFocused
                      ? Color.primary : Color.gray.opacity(0.75),
                    lineWidth: 2
                  )
              )
              .cornerRadius(8)
              .textContentType(.password)
              #if os(iOS)
                .autocapitalization(.none)
              #else
                .textFieldStyle(.plain)
              #endif
              .autocorrectionDisabled()
              .focused($isPasswordFieldFocused)
          }
        }
      }
      .frame(maxHeight: .infinity, alignment: .topLeading)
      .safeAreaInset(edge: .bottom) {
        VStack {
          Button(action: {
            withAnimation {
              isUsingPassword.toggle()
            }
          }) {
            Text("Sign in with \(isUsingPassword ? "email code" : "password")")
              .fontWeight(.bold)
              .frame(maxWidth: .infinity)
          }
          .controlSize(.large)
          .disabled(authManager.isLoading)
          .padding()

          #if os(iOS)
            AsyncActionButton(
              title: "Continue",
              isLoading: authManager.isLoading,
              isDisabled: authManager.isLoading
                || identifier.isEmpty || (isUsingPassword && password.isEmpty)
            ) {
              await handleSubmit()
            }
          #endif
        }
      }
      .padding()
      .navigationTitle("Sign In")
      .toolbar {
        ToolbarItem(
          placement: {
            #if os(iOS)
              .topBarTrailing
            #else
              .destructiveAction
            #endif
          }()
        ) {
          #if os(iOS)
            if #available(iOS 26.0, *) {
              Button(role: .close, action: { dismiss() })
            } else {
              Button {
                dismiss()
              } label: {
                Image(systemName: "xmark.circle.fill")
                  .opacity(0.8)
              }
              .buttonStyle(.plain)
            }
          #else
            Button("Cancel") {
              dismiss()
            }
            .fontWeight(.bold)
            .controlSize(.large)
          #endif
        }

        #if os(macOS)
          ToolbarItem(placement: .confirmationAction) {
            AsyncActionButton(
              title: "Continue",
              isLoading: authManager.isLoading,
              isDisabled: authManager.isLoading
                || identifier.isEmpty || (isUsingPassword && password.isEmpty)
            ) {
              await handleSubmit()
            }
          }
        #endif
      }
      .navigationDestination(isPresented: $isShowingOtcVerify) {
        OneTimeCodeView(identifier: identifier)
      }
      .alert(isPresented: $showError) {
        Alert(
          title: Text("Sign In Failed"),
          message: Text(
            errorMessage.isEmpty
              ? "Try again with a different Username or Email." : errorMessage
          ),
          dismissButton: .default(Text("OK"))
        )
      }
    }
  }

  private func handleSubmit() async {
    if isUsingPassword {
      let (success, err) = await authManager.signInWithPassword(
        identifier: identifier,
        password: password
      )
      if !success {
        errorMessage = err
        showError = true
      }
    } else {
      let success = await authManager.requestOneTimeCode(for: identifier)
      if success {
        isShowingOtcVerify = true
      } else {
        errorMessage =
          "Failed to send code. Try again with a different Username or Email."
        showError = true
      }
    }
  }
}

#Preview {
  LoginView()
    .environment(AuthManager())
}
