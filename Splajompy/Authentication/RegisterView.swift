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
            .padding(.bottom, usernameError.isEmpty ? 10 : 4)
            .focused($isUsernameFieldFocused)
            .onAppear {
              isUsernameFieldFocused = true
            }
            .onSubmit {
              usernameError = authManager.validateUsername(username) ?? ""
            }

          if !usernameError.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
              Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)
                .font(.callout)

              Text(usernameError)
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
            .padding(.bottom, emailError.isEmpty ? 10 : 4)
            .focused($isEmailFieldFocused)
            .onSubmit {
              emailError = authManager.validateEmail(email) ?? ""
            }

          if !emailError.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
              Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)
                .font(.callout)

              Text(emailError)
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
            .padding(.bottom, passwordError.isEmpty ? 0 : 4)
            .onSubmit {
              passwordError = authManager.validatePassword(password) ?? ""
            }

          if !passwordError.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
              Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)
                .font(.callout)

              Text(passwordError)
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

          if !errorMessage.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
              Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.white)
                .font(.callout)

              Text(
                errorMessage.isEmpty
                  ? "An unknown error occurred." : errorMessage
              )
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
      .animation(.easeInOut(duration: 0.25), value: usernameError.isEmpty)
      .animation(.easeInOut(duration: 0.25), value: emailError.isEmpty)
      .animation(.easeInOut(duration: 0.25), value: passwordError.isEmpty)
    }
  }

  private func validateForm() -> Bool {
    errorMessage = ""

    // Use AuthManager validation methods
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
