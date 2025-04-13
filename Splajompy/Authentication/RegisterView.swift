import SwiftUI

struct RegisterView: View {
  @Environment(\.dismiss) var dismiss

  @State private var username = ""
  @State private var email = ""
  @State private var password = ""

  @State private var usernameError: String = ""
  @State private var emailError: String = ""
  @State private var passwordError: String = ""
  @State private var isFormValid: Bool = false
  @State private var showError: Bool = false
  @State private var errorMessage: String = ""

  @EnvironmentObject private var authManager: AuthManager
  @Environment(\.colorScheme) var colorScheme

  var body: some View {
    NavigationView {
      VStack(spacing: 6) {
        Image("Logo")
          .resizable()
          .scaledToFit()
          .frame(width: 100, height: 100)
          .shadow(color: .white.opacity(0.4), radius: 15, x: 0, y: 0)
          .padding(.bottom, 28)

        Text("Create account")
          .font(.system(size: 24, weight: .black))
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.bottom, 20)

        VStack(alignment: .leading, spacing: 5) {
          TextField("Username", text: $username)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .textContentType(.username)
            .autocapitalization(.none)
            .autocorrectionDisabled()
            .onChange(of: username) { oldValue, newValue in
              validateForm()
            }

          if !usernameError.isEmpty {
            Text(usernameError)
              .font(.caption)
              .foregroundColor(.red)
              .padding(.leading, 4)
          }
        }
        .padding(.bottom, 10)

        VStack(alignment: .leading, spacing: 5) {
          TextField("Email", text: $email)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .autocapitalization(.none)
            .autocorrectionDisabled()
            .onChange(of: email) { oldValue, newValue in
              validateForm()
            }

          if !emailError.isEmpty {
            Text(emailError)
              .font(.caption)
              .foregroundColor(.red)
              .padding(.leading, 4)
          }
        }
        .padding(.bottom, 10)

        VStack(alignment: .leading, spacing: 5) {
          SecureField("Password", text: $password)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .textContentType(.newPassword)
            .onChange(of: password) { oldValue, newValue in
              validateForm()
            }

          if !passwordError.isEmpty {
            Text(passwordError)
              .font(.caption)
              .foregroundColor(.red)
              .padding(.leading, 4)
          }
        }
        .padding(.bottom, 10)

        Spacer()

        Button(action: {
          if validateFormOnSubmit() {
            register()
          }
        }) {
          ZStack {
            HStack {
              Spacer()
              Text("Register")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
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
          .background(isFormValid ? Color.accentColor : Color.gray.opacity(0.3))
          .cornerRadius(8)
        }
        .disabled(authManager.isLoading || !isFormValid)
        .padding(.bottom, 16)
      }
      .padding(.horizontal, 24)
      .padding(.vertical, 32)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button(action: {
            dismiss()
          }) {
            Image(systemName: "xmark")
              .font(.system(size: 16, weight: .bold))
              .foregroundColor(.primary)
              .padding(8)
              .background(Color(.systemGray6))
              .clipShape(Circle())
          }
        }
      }
    }
    .navigationViewStyle(StackNavigationViewStyle())
    .alert(isPresented: $showError) {
      Alert(
        title: Text("Registration Failed"),
        message: Text(errorMessage),
        dismissButton: .default(Text("OK"))
      )
    }
  }

  func register() {
    Task {
      let result = await authManager.register(
        username: username,
        email: email,
        password: password
      )

      await MainActor.run {
        switch result {
        case .success:
          print("Registration successful!")

        case .usernameError(let message):
          usernameError = message
          showError = true
          errorMessage = message

        case .emailError(let message):
          emailError = message
          showError = true
          errorMessage = message

        case .passwordError(let message):
          passwordError = message
          showError = true
          errorMessage = message

        case .generalError(let message):
          showError = true
          errorMessage = message
        }
      }
    }
  }

  private func validateForm() {
    usernameError = ""
    emailError = ""
    passwordError = ""

    if !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !password.isEmpty
    {
      isFormValid = true
    } else {
      isFormValid = false
    }
  }

  private func validateFormOnSubmit() -> Bool {
    var isValid = true

    if username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      usernameError = "Username is required"
      isValid = false
    }

    if email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      emailError = "Email is required"
      isValid = false
    } else if !isValidEmail(email) {
      emailError = "Please enter a valid email"
      isValid = false
    }

    if password.isEmpty {
      passwordError = "Password is required"
      isValid = false
    }

    return isValid
  }

  func isValidEmail(_ email: String) -> Bool {
    let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
    let emailPred = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
    return emailPred.evaluate(with: email)
  }
}

#Preview {
  RegisterView()
    .environmentObject(AuthManager())
}

// This extension is kept the same as in the original code
extension AuthManager {
  enum RegistrationResult {
    case success
    case usernameError(String)
    case emailError(String)
    case passwordError(String)
    case generalError(String)
  }

  func register(username: String, email: String, password: String) async
    -> RegistrationResult
  {
    // Implement your registration logic here
    // This is a placeholder implementation
    return .success
  }
}
