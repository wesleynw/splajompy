import PostHog
import SwiftUI

struct LoginView: View {
  @Environment(\.dismiss) var dismiss
  @Environment(AuthManager.self) private var authManager

  @State private var identifier: String = ""
  @State private var isUsingPassword: Bool = true
  @State private var isShowingOtcVerify: Bool = false
  @State private var password = ""
  @State private var hasRequestedCode: Bool = false

  @State private var showError: Bool = false
  @State private var errorMessage: String = ""

  @FocusState private var isIdentifierFieldFocused: Bool
  @FocusState private var isPasswordFieldFocused: Bool

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 15) {
          TextField("Username or Email", text: $identifier)
            .textContentType(.emailAddress)
            .padding()
            .background {
              RoundedRectangle(cornerRadius: 10)
                .stroke(isIdentifierFieldFocused ? .primary : .secondary)
            }
            #if os(iOS)
              .autocorrectionDisabled()
            #else
              .textFieldStyle(.plain)
            #endif
            .focused($isIdentifierFieldFocused)

          if isUsingPassword {
            SecureField("Password", text: $password)
              .textContentType(.password)
              .padding()
              .background {
                RoundedRectangle(cornerRadius: 10)
                  .stroke(isIdentifierFieldFocused ? .primary : .secondary)
              }
              #if os(iOS)
                .autocapitalization(.none)
              #else
                .textFieldStyle(.plain)
              #endif
              .autocorrectionDisabled()
              .focused($isPasswordFieldFocused)
          }
        }
        .padding()
      }
      .onAppear {
        if identifier.isEmpty {
          isIdentifierFieldFocused = true
        } else {
          isPasswordFieldFocused = true
        }
      }
      .safeAreaInset(edge: .bottom) {
        VStack {
          Button(action: {
            withAnimation {
              isUsingPassword.toggle()
            }
          }) {
            Text("Sign in with \(isUsingPassword ? "email code" : "password")")
              .font(SJFont.callout)
              .frame(maxWidth: .infinity)
          }
          .controlSize(.large)
          .disabled(authManager.isLoading)
          .padding()

          AsyncActionButton(
            title: "Continue",
            isLoading: authManager.isLoading,
            isDisabled: authManager.isLoading
              || identifier.isEmpty || (isUsingPassword && password.isEmpty)
          ) {
            await handleSubmit()
          }
        }
        .padding()
      }
      .pageTitle("Sign In")
      .toolbar {
        ToolbarItem(
          placement: {
            #if os(iOS)
              .cancellationAction
            #else
              .destructiveAction
            #endif
          }()
        ) {
          if #available(iOS 26, macOS 26, *) {
            Button(role: .cancel, action: { dismiss() })
          } else {
            Button {
              dismiss()
            } label: {
              Image(systemName: "xmark.circle.fill")
                .opacity(0.8)
            }
            .buttonStyle(.plain)
          }
        }
      }
      .navigationDestination(isPresented: $isShowingOtcVerify) {
        OneTimeCodeView(identifier: identifier)
          .postHogScreenView()
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
