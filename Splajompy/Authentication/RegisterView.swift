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
          TextField("Username", text: $username)
            .padding(12)
            .background(
              RoundedRectangle(cornerRadius: 8)
                .stroke(
                  isUsernameFieldFocused
                    ? Color.primary : Color.gray.opacity(0.75),
                  lineWidth: 2
                )
            )
            .cornerRadius(8)
            .textContentType(.username)
            .autocapitalization(.none)
            .autocorrectionDisabled()
            .padding(.bottom, 10)
            .focused($isUsernameFieldFocused)
            .onAppear {
              isUsernameFieldFocused = true
            }
            .onChange(of: username) {
              if isUsernameFieldFocused { usernameError = "" }
            }
            .onSubmit {
              _ = validateUsername()
            }

          if !usernameError.isEmpty {
            Text(usernameError)
              .font(.subheadline)
              .foregroundColor(.red.opacity(0.9))
              .padding(.bottom, 8)
              .transition(.opacity)
          }

          TextField("Email", text: $email)
            .padding(12)
            .background(
              RoundedRectangle(cornerRadius: 8)
                .stroke(
                  isEmailFieldFocused
                    ? Color.primary : Color.gray.opacity(0.75),
                  lineWidth: 2
                )
            )
            .cornerRadius(8)
            .textContentType(.emailAddress)
            .autocapitalization(.none)
            .autocorrectionDisabled()
            .padding(.bottom, 10)
            .focused($isEmailFieldFocused)
            .onChange(of: email) {
              if isEmailFieldFocused { emailError = "" }
            }
            .onSubmit {
              _ = validateEmail()
            }

          if !emailError.isEmpty {
            Text(emailError)
              .font(.subheadline)
              .foregroundColor(.red.opacity(0.9))
              .padding(.bottom, 8)
              .transition(.opacity)
          }

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
            .autocapitalization(.none)
            .autocorrectionDisabled()
            .focused($isPasswordFieldFocused)
            .onChange(of: password) {
              if isPasswordFieldFocused { passwordError = "" }
            }
            .onSubmit {
              _ = validatePassword()
            }

          if !passwordError.isEmpty {
            Text(passwordError)
              .font(.subheadline)
              .foregroundColor(.red.opacity(0.9))
              .padding(.bottom, 8)
              .transition(.opacity)
          }

          if !errorMessage.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
              Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.white)

              Text(
                errorMessage.isEmpty
                  ? "An unknown error occurred." : errorMessage
              )
              .font(.callout)
              .foregroundColor(.white)
              .multilineTextAlignment(.leading)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.9))
            .cornerRadius(10)
            .padding(.top, 20)
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.easeInOut(duration: 0.3), value: errorMessage.isEmpty)
          }
        }
        .padding(.bottom, 10)

        Spacer()

        VStack(spacing: 12) {
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
              UIApplication.shared.open(url)
              return .handled
            })
        }
        .padding(.bottom, 16)

        Button(action: {
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
        ) {
          ZStack {
            HStack {
              Spacer()
              Text("Continue")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(
                  (username.isEmpty || email.isEmpty || password.isEmpty)
                    ? Color.white.opacity(0.4) : Color.white
                )
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
          .background(
            (username.isEmpty || email.isEmpty || password.isEmpty)
              ? Color.gray.opacity(0.3) : Color.accentColor
          )
          .cornerRadius(10)
        }
        .disabled(
          authManager.isLoading || username.isEmpty || email.isEmpty
            || password.isEmpty
        )
        .padding(.bottom, 8)
      }
      .padding(.horizontal, 24)
      .padding(.vertical, 32)
      .navigationTitle("Register")
      .navigationBarBackButtonHidden()
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button(action: {
            isPresenting = false
          }) {
            Image(systemName: "xmark")
              .font(.system(size: 15, weight: .bold))
              .foregroundColor(.primary.opacity(0.5))
              .padding(8)
              .background(Color(.systemGray6))
              .clipShape(Circle())
          }
          .sensoryFeedback(.impact, trigger: isPresenting)
        }
      }
      .animation(.easeInOut(duration: 0.2), value: usernameError)
      .animation(.easeInOut(duration: 0.2), value: emailError)
      .animation(.easeInOut(duration: 0.2), value: passwordError)
    }
  }

  private func validateUsername() -> Bool {
    if username.isEmpty {
      usernameError = "Username cannot be empty"
      return false
    }

    if username.count < 3 {
      usernameError = "Username must be at least 3 characters"
      return false
    }

    usernameError = ""
    return true
  }

  private func validateEmail() -> Bool {
    if email.isEmpty {
      emailError = "Email cannot be empty"
      return false
    }

    let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
    let emailPred = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
    if !emailPred.evaluate(with: email) {
      emailError = "Please enter a valid email address"
      return false
    }

    emailError = ""
    return true
  }

  private func validatePassword() -> Bool {
    if password.isEmpty {
      passwordError = "Password cannot be empty"
      return false
    }

    if password.count < 8 {
      passwordError = "Password must be at least 8 characters"
      return false
    }

    passwordError = ""
    return true
  }

  private func validateForm() -> Bool {
    let isUsernameValid = validateUsername()
    let isEmailValid = validateEmail()
    let isPasswordValid = validatePassword()

    return isUsernameValid && isEmailValid && isPasswordValid
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
