import SwiftUI

struct LoginView: View {
  @Environment(\.dismiss) var dismiss

  @State private var identifier: String = ""
  @State private var isUsingPassword: Bool = false
  @State private var isShowingOtcVerify: Bool = false
  @State private var password = ""
  @State private var hasRequestedCode: Bool = false

  @State var showError: Bool = false
  @State var errorMessage: String = ""

  @FocusState private var isIdentifierFieldFocused: Bool
  @FocusState private var isPasswordFieldFocused: Bool

  @EnvironmentObject private var authManager: AuthManager

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
              .font(.system(size: 16, weight: .bold))
              .padding()
              .frame(maxWidth: .infinity)
          }
          .disabled(authManager.isLoading)

          AsyncActionButton(
            title: "Continue",
            isLoading: authManager.isLoading,
            isDisabled: authManager.isLoading
              || identifier.isEmpty || (isUsingPassword && password.isEmpty)
          ) {
            if isUsingPassword {
              Task {
                let (success, err) = await authManager.signInWithPassword(
                  identifier: identifier,
                  password: password
                )
                if !success {
                  errorMessage = err
                  showError = true
                }
              }
            } else {
              let success = await authManager.requestOneTimeCode(
                for: identifier
              )
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
      }
      .padding()
      .navigationTitle("Sign In")
      .toolbar {
        ToolbarItem(
          placement: {
            #if os(iOS)
              .topBarTrailing
            #else
              .primaryAction
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
            CloseButton(onClose: { dismiss() })
          #endif
        }
      }
      .navigationDestination(isPresented: $isShowingOtcVerify) {
        OneTimeCodeView(identifier: identifier)
          .environmentObject(authManager)
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
}

#Preview {
  LoginView()
    .environmentObject(AuthManager())
}
