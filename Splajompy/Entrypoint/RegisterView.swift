import PostHog
import SwiftUI

struct RegisterView: View {
  @Environment(\.dismiss) var dismiss
  @Environment(AuthManager.self) private var authManager

  @State private var email: String = ""
  @State private var username: String = ""
  @State private var password = ""

  @State private var usernameError: String = ""
  @State private var emailError: String = ""
  @State private var passwordError: String = ""

  @State var errorMessage: String = ""

  @FocusState private var isUsernameFieldFocused: Bool
  @FocusState private var isEmailFieldFocused: Bool
  @FocusState private var isPasswordFieldFocused: Bool

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 15) {
          usernameField
          usernameErrorView
          emailField
          emailErrorView
          passwordField
          passwordErrorView
          generalErrorView
        }
        .padding()
      }
      .safeAreaInset(edge: .bottom) {
        VStack {
          termsText

          AsyncActionButton(
            title: "Continue",
            isLoading: authManager.isLoading,
            isDisabled: isContinueButtonDisabled
          ) {
            handleContinue()
          }
          .padding()
        }
        .toolbar {
          ToolbarItem(
            placement: {
              #if os(iOS)
                return .cancellationAction
              #else
                return .destructiveAction
              #endif
            }()
          ) {
            if #available(iOS 26.0, macOS 26, *) {
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
          }
        }
      }
      .onAppear {
        isUsernameFieldFocused = true
      }
      .pageTitle("Register")
      .animation(.easeInOut(duration: 0.25), value: usernameError.isEmpty)
      .animation(.easeInOut(duration: 0.25), value: emailError.isEmpty)
      .animation(.easeInOut(duration: 0.25), value: passwordError.isEmpty)
    }
  }

  private var usernameField: some View {
    TextField("Username", text: $username)
      .textContentType(.username)
      .padding()
      .background {
        RoundedRectangle(cornerRadius: 10)
          .stroke(isUsernameFieldFocused ? .primary : .secondary)
      }
      #if os(iOS)
        .autocapitalization(.none)
        .autocorrectionDisabled()
      #else
        .textFieldStyle(.plain)
      #endif
      .focused($isUsernameFieldFocused)
      .onSubmit {
        usernameError = authManager.validateUsername(username) ?? ""
      }
  }

  @ViewBuilder
  private var usernameErrorView: some View {
    if !usernameError.isEmpty {
      errorMessageView(usernameError)
    }
  }

  private var emailField: some View {
    TextField("Email", text: $email)
      .padding()
      .background {
        RoundedRectangle(cornerRadius: 10)
          .stroke(isUsernameFieldFocused ? .primary : .secondary)
      }
      .textContentType(.emailAddress)
      #if os(iOS)
        .autocapitalization(.none)
        .autocorrectionDisabled()
      #else
        .textFieldStyle(.plain)
      #endif
      .focused($isEmailFieldFocused)
      .onSubmit {
        emailError = authManager.validateEmail(email) ?? ""
      }
  }

  @ViewBuilder
  private var emailErrorView: some View {
    if !emailError.isEmpty {
      errorMessageView(emailError)
    }
  }

  private var passwordField: some View {
    SecureField("Password", text: $password)
      .padding()
      .background {
        RoundedRectangle(cornerRadius: 10)
          .stroke(isUsernameFieldFocused ? .primary : .secondary)
      }
      .textContentType(.newPassword)
      #if os(iOS)
        .autocapitalization(.none)
        .autocorrectionDisabled()
      #else
        .textFieldStyle(.plain)
      #endif
      .focused($isPasswordFieldFocused)
      .onSubmit {
        passwordError = authManager.validatePassword(password) ?? ""
      }
  }

  @ViewBuilder
  private var passwordErrorView: some View {
    if !passwordError.isEmpty {
      errorMessageView(passwordError)
    }
  }

  @ViewBuilder
  private var generalErrorView: some View {
    if !errorMessage.isEmpty {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Image(systemName: "exclamationmark.triangle.fill")
          .foregroundStyle(.white)
          .font(.callout)

        Text(errorMessage.isEmpty ? "An unknown error occurred." : errorMessage)
          .font(.callout)
          .foregroundStyle(.white)
          .multilineTextAlignment(.leading)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 8)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.red)
      .cornerRadius(8)
      .padding(.top, 16)
      .transition(.move(edge: .top).combined(with: .opacity))
      .animation(.easeInOut(duration: 0.3), value: errorMessage.isEmpty)
    }
  }

  private var termsText: some View {
    Text(
      "By continuing, you agree to our [Terms of Service](https://splajompy.com/tos) and [Privacy Policy](https://splajompy.com/privacy)."
    )
    .font(SJFont.body)
    .foregroundStyle(.secondary)
    .multilineTextAlignment(.center)
    .environment(
      \.openURL,
      OpenURLAction { url in
        #if os(iOS)
          UIApplication.shared.open(url)
        #else
          NSWorkspace.shared.open(url)
        #endif
        return .handled
      }
    )
  }

  private func errorMessageView(_ message: String) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 6) {
      Image(systemName: "exclamationmark.circle.fill")
        .foregroundStyle(.red)
        .font(.callout)

      Text(message)
        .font(.callout)
        .foregroundStyle(.red)
        .multilineTextAlignment(.leading)
    }
    .padding(.horizontal, 6)
    .padding(.vertical, 4)
    .background(Color.red.opacity(0.1))
    .cornerRadius(6)
    .padding(.bottom, 12)
    .transition(.opacity.combined(with: .move(edge: .top)))
  }

  private func fieldBorderColor(focused: Bool) -> Color {
    focused ? Color.primary : Color.gray.opacity(0.75)
  }

  private var isFormEmpty: Bool {
    username.isEmpty || email.isEmpty || password.isEmpty
  }

  private var continueButtonTextColor: Color {
    isFormEmpty ? Color.white.opacity(0.4) : Color.white
  }

  private var continueButtonBackgroundColor: Color {
    isFormEmpty ? Color.gray.opacity(0.3) : Color.accentColor
  }

  private var isContinueButtonDisabled: Bool {
    authManager.isLoading || isFormEmpty
  }

  private func handleContinue() {
    if validateForm() {
      Task {
        let (success, err) = await authManager.register(
          username: username,
          email: email,
          password: password
        )
        if !success {
          withAnimation {
            errorMessage = err
          }
        }
      }
    }
  }

  private func validateForm() -> Bool {
    errorMessage = ""

    usernameError = authManager.validateUsername(username) ?? ""
    emailError = authManager.validateEmail(email) ?? ""
    passwordError = authManager.validatePassword(password) ?? ""

    return usernameError.isEmpty && emailError.isEmpty && passwordError.isEmpty
  }
}

#Preview {
  RegisterView()
    .environment(AuthManager())
}
