import SwiftUI

struct RegisterView: View {
  @Binding var isPresenting: Bool
  @Environment(\.dismiss) var dismiss

  @State private var email: String = ""
  @State private var username: String = ""
  @State private var password = ""

  @State private var usernameError: String = ""
  @State private var emailError: String = ""
  @State private var passwordError: String = ""

  @FocusState private var isUsernameFieldFocused: Bool
  @FocusState private var isEmailFieldFocused: Bool
  @FocusState private var isPasswordFieldFocused: Bool

  @State var errorMessage: String = ""

  @EnvironmentObject private var authManager: AuthManager

  var body: some View {
    NavigationStack {
      VStack {
        VStack(alignment: .leading, spacing: 5) {
          usernameField
          usernameErrorView
          emailField
          emailErrorView
          passwordField
          passwordErrorView
          generalErrorView
        }
        .padding(.bottom, 10)

        Spacer()

        bottomSection
      }
      .padding(.horizontal, 24)
      .padding(.vertical, 32)
      .navigationTitle("Register")
      .navigationBarBackButtonHidden()
      .toolbar {
        ToolbarItem(placement: toolbarPlacement) {
          closeButton
        }
      }
      .animation(.easeInOut(duration: 0.25), value: usernameError.isEmpty)
      .animation(.easeInOut(duration: 0.25), value: emailError.isEmpty)
      .animation(.easeInOut(duration: 0.25), value: passwordError.isEmpty)
    }
  }

  private var usernameField: some View {
    TextField("Username", text: $username)
      .padding(12)
      .background(
        RoundedRectangle(cornerRadius: 8)
          .stroke(
            fieldBorderColor(focused: isUsernameFieldFocused),
            lineWidth: 2
          )
      )
      .cornerRadius(8)
      .textContentType(.username)
      #if os(iOS)
        .autocapitalization(.none)
        .autocorrectionDisabled()
      #endif
      .padding(.bottom, usernameError.isEmpty ? 10 : 4)
      .focused($isUsernameFieldFocused)
      .onAppear {
        isUsernameFieldFocused = true
      }
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
      .padding(12)
      .background(
        RoundedRectangle(cornerRadius: 8)
          .stroke(fieldBorderColor(focused: isEmailFieldFocused), lineWidth: 2)
      )
      .cornerRadius(8)
      .textContentType(.emailAddress)
      #if os(iOS)
        .autocapitalization(.none)
        .autocorrectionDisabled()
      #endif
      .padding(.bottom, emailError.isEmpty ? 10 : 4)
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
      .padding(12)
      .background(
        RoundedRectangle(cornerRadius: 8)
          .stroke(
            fieldBorderColor(focused: isPasswordFieldFocused),
            lineWidth: 2
          )
      )
      .cornerRadius(8)
      .textContentType(.password)
      #if os(iOS)
        .autocapitalization(.none)
        .autocorrectionDisabled()
      #endif
      .focused($isPasswordFieldFocused)
      .padding(.bottom, passwordError.isEmpty ? 0 : 4)
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
          .foregroundColor(.white)
          .font(.callout)

        Text(errorMessage.isEmpty ? "An unknown error occurred." : errorMessage)
          .font(.callout)
          .foregroundColor(.white)
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

  private var bottomSection: some View {
    VStack(spacing: 12) {
      termsText
      continueButton
    }
    .padding(.bottom, 8)
  }

  private var termsText: some View {
    Text(
      "By continuing, you agree to our [Terms of Service](https://splajompy.com/terms) and [Privacy Policy](https://splajompy.com/privacy)."
    )
    .font(.caption)
    .foregroundColor(.secondary)
    .multilineTextAlignment(.center)
    .fixedSize(horizontal: false, vertical: true)
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
    .padding(.bottom, 16)
  }

  private var continueButton: some View {
    Button(action: handleContinue) {
      ZStack {
        HStack {
          Spacer()
          Text("Continue")
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(continueButtonTextColor)
            .padding()
          Spacer()
        }

        if authManager.isLoading {
          HStack {
            Spacer()
            ProgressView()
              .progressViewStyle(CircularProgressViewStyle(tint: .white))
              .padding(.trailing, 16)
          }
        }
      }
      .background(continueButtonBackgroundColor)
      .cornerRadius(10)
    }
    .disabled(isContinueButtonDisabled)
  }

  private var closeButton: some View {
    Button(action: {
      isPresenting = false
    }) {
      Image(systemName: "xmark")
        .font(.system(size: 15, weight: .bold))
        .foregroundColor(.primary.opacity(0.5))
        .padding(8)
        .background(backgroundColorForCloseButton)
        .clipShape(Circle())
    }
    .sensoryFeedback(.impact, trigger: isPresenting)
  }

  private func errorMessageView(_ message: String) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 6) {
      Image(systemName: "exclamationmark.circle.fill")
        .foregroundColor(.red)
        .font(.callout)

      Text(message)
        .font(.callout)
        .foregroundColor(.red)
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

  private var backgroundColorForCloseButton: Color {
    #if os(iOS)
      return Color(.systemGray6)
    #else
      return Color(.controlBackgroundColor)
    #endif
  }

  private var toolbarPlacement: ToolbarItemPlacement {
    #if os(iOS)
      return .topBarTrailing
    #else
      return .primaryAction
    #endif
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
  @Previewable @State var isPresenting = true
  @Previewable @State var identifier = "wesleynw@pm.me"

  CredentialedLoginView(isPresenting: $isPresenting, identifier: $identifier)
    .environmentObject(AuthManager())
}

#Preview("Dark Mode") {
  @Previewable @State var isPresenting = true
  @Previewable @State var identifier = "wesleynw@pm.me"

  CredentialedLoginView(isPresenting: $isPresenting, identifier: $identifier)
    .environmentObject(AuthManager())
    .preferredColorScheme(.dark)
}
