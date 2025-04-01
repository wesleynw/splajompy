//
//  RegistrationView.swift
//  Splajompy
//
//  Created by Wesley Weisenberger on 3/28/25.
//

import SwiftUI

struct RegistrationView: View {
  @State private var username = ""
  @State private var email = ""
  @State private var password = ""
  @State private var usernameError: String? = nil
  @State private var emailError: String? = nil
  @State private var passwordError: String? = nil
  @State private var isRegistering = false

  @EnvironmentObject private var authManager: AuthManager
  @Environment(\.dismiss) private var dismiss
  @Environment(\.colorScheme) var colorScheme

  var body: some View {
    ZStack {
      Color(.systemBackground).edgesIgnoringSafeArea(.all)

      VStack {
        Spacer()  // Pushes content down from top

        ScrollView {
          VStack(alignment: .center, spacing: 0) {
            Image(colorScheme == .dark ? "S_transparent_white" : "S_transparent_black")
              .resizable()
              .scaledToFit()
              .frame(width: 100, height: 100)
              .shadow(color: .white.opacity(0.4), radius: 15, x: 0, y: 0)
              .padding(.bottom, 28)

            // Registration Header
            Text("Register")
              .font(.system(size: 24, weight: .black))
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.bottom, 20)

            // Username Field
            VStack(alignment: .leading, spacing: 5) {
              TextField("Username", text: $username)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .autocapitalization(.none)
                .autocorrectionDisabled()

              if let error = usernameError {
                Text(error)
                  .foregroundColor(.red)
                  .font(.caption)
                  .padding(.leading, 4)
              }
            }
            .padding(.bottom, 10)

            // Email Field
            VStack(alignment: .leading, spacing: 5) {
              TextField("Email", text: $email)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .keyboardType(.emailAddress)

              if let error = emailError {
                Text(error)
                  .foregroundColor(.red)
                  .font(.caption)
                  .padding(.leading, 4)
              }
            }
            .padding(.bottom, 10)

            // Password Field
            VStack(alignment: .leading, spacing: 5) {
              SecureField("Password", text: $password)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)

              if let error = passwordError {
                Text(error)
                  .foregroundColor(.red)
                  .font(.caption)
                  .padding(.leading, 4)
              }
            }
            .padding(.bottom, 20)

            // Register Button
            Button(action: register) {
              HStack {
                if isRegistering {
                  ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .padding(.trailing, 10)
                }

                Text("Register")
                  .font(.system(size: 16, weight: .bold))
                  .foregroundColor(.white)
                  .frame(maxWidth: .infinity)
              }
              .padding()
              .background(Color.blue)
              .cornerRadius(8)
            }
            .disabled(isRegistering)
            .padding(.bottom, 16)

            // Login Section
            HStack(spacing: 10) {
              Text("Already have an account?")
                .fontWeight(.bold)

              Button(action: {
                dismiss()
              }) {
                Text("Login")
                  .fontWeight(.bold)
                  .underline()
              }
            }
          }
          .padding(.horizontal, 24)
          .padding(.vertical, 32)
          .frame(maxWidth: 450)
        }

        Spacer()
      }
    }
  }

  func register() {
    usernameError = nil
    emailError = nil
    passwordError = nil

    if username.isEmpty {
      usernameError = "Username is required"
      return
    }

    if email.isEmpty {
      emailError = "Email is required"
      return
    }

    if !isValidEmail(email) {
      emailError = "Please enter a valid email"
      return
    }

    if password.isEmpty {
      passwordError = "Password is required"
      return
    }

    isRegistering = true

    Task {
      let result = await authManager.register(username: username, email: email, password: password)

      DispatchQueue.main.async {
        isRegistering = false

        switch result {
        case .success:
          print("Registration successful!")

        case .usernameError(let message):
          usernameError = message

        case .emailError(let message):
          emailError = message

        case .passwordError(let message):
          passwordError = message

        case .generalError(let message):
          // Handle general error
          print("Registration error: \(message)")
        }
      }
    }
  }

  func isValidEmail(_ email: String) -> Bool {
    let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
    let emailPred = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
    return emailPred.evaluate(with: email)
  }
}

#Preview {
  RegistrationView()
    .environmentObject(AuthManager())
}

// This extension assumes you have an AuthManager class with a registration method
// You'll need to implement this method in your AuthManager class
extension AuthManager {
  enum RegistrationResult {
    case success
    case usernameError(String)
    case emailError(String)
    case passwordError(String)
    case generalError(String)
  }

  func register(username: String, email: String, password: String) async -> RegistrationResult {
    // Implement your registration logic here
    // This is a placeholder implementation
    return .success
  }
}
