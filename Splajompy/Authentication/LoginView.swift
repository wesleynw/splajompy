import SwiftUI

struct LoginView: View {
  @State private var identifier = ""
  @State private var password = ""
  @State private var isUsingPassword = true
  @State private var showRegistration = false

  @State private var identifierError: String = ""
  @State private var passwordError: String = ""
  @State private var isFormValid: Bool = false
  @State private var showError: Bool = false
  @State private var errorMessage: String = ""

  @EnvironmentObject private var authManager: AuthManager
  @Environment(\.colorScheme) var colorScheme

  var body: some View {
    ScrollView {
      VStack(spacing: 6) {
        Image(colorScheme == .dark ? "S_transparent_white" : "S_transparent_black")
          .resizable()
          .scaledToFit()
          .frame(width: 100, height: 100)
          .shadow(color: .white.opacity(0.4), radius: 15, x: 0, y: 0)
          .padding(.bottom, 28)

        Text("Sign in")
          .font(.system(size: 24, weight: .black))
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.bottom, 20)

        VStack(alignment: .leading, spacing: 5) {
          TextField("Email or Username", text: $identifier)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .textContentType(.username)
            .autocapitalization(.none)
            .autocorrectionDisabled()
            .onChange(of: identifier) { oldValue, newValue in
              validateForm()
            }

          if !identifierError.isEmpty {
            Text(identifierError)
              .font(.caption)
              .foregroundColor(.red)
              .padding(.leading, 4)
          }
        }
        .padding(.bottom, 10)

        if isUsingPassword {
          VStack(alignment: .leading, spacing: 5) {
            SecureField("Password", text: $password)
              .padding()
              .background(Color(.systemGray6))
              .cornerRadius(8)
              .textContentType(.password)
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
        }

        // TODO
        //                HStack {
        //                    Spacer()
        //                    Button(action: {
        //                        isUsingPassword.toggle()
        //                    }) {
        //                        Text("Sign in with \(isUsingPassword ? "username or email" : "password")")
        //                            .font(.system(size: 14, weight: .bold))
        //                    }
        //                }
        //                .padding(.bottom, 16)

        Button(action: {
          if validateFormOnSubmit() {
            signIn()
          }
        }) {
          ZStack {
            HStack {
              Spacer()
              Text("Continue")
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
          .background(isFormValid ? Color.blue : Color.blue.opacity(0.6))
          .cornerRadius(8)
        }
        .disabled(authManager.isLoading || !isFormValid)
        .padding(.bottom, 16)

        // TODO
        //                HStack(spacing: 10) {
        //                    Text("New here?")
        //                        .fontWeight(.bold)
        //
        //                    Button(action: {
        //                        showRegistration = true
        //                    }) {
        //                        Text("Register")
        //                            .fontWeight(.bold)
        //                            .underline()
        //                    }.fullScreenCover(isPresented: $showRegistration) {
        //                        RegistrationView()
        //                            .environmentObject(authManager)
        //                    }
        //                }
      }
      .padding(.horizontal, 24)
      .padding(.vertical, 32)
    }
    .alert(isPresented: $showError) {
      Alert(
        title: Text("Sign In Failed"),
        message: Text(errorMessage),
        dismissButton: .default(Text("OK"))
      )
    }
  }

  func signIn() {
    Task {
      if isUsingPassword {
        let authError = await authManager.signInWithPassword(
          identifier: identifier, password: password)
        if authError == .none {
          print("Authentication successful!")
        } else {
          await MainActor.run {
            switch authError {
            case .incorrectPassword:
              errorMessage = "Wrong password"
            case .accountNonexistent:
              errorMessage = "Account doesn't exist"
            default:
              errorMessage = "Authentication error: \(authError)"
            }
            showError = true
          }
        }
      } else {
        // TODO
        print("Requesting email authentication for: \(identifier)")
      }
    }
  }

  private func validateForm() {
    // Clear previous errors
    identifierError = ""
    passwordError = ""

    // Check for non-empty values
    if !identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && (!isUsingPassword || !password.isEmpty)
    {
      isFormValid = true
    } else {
      isFormValid = false
    }
  }

  private func validateFormOnSubmit() -> Bool {
    var isValid = true

    // Validate identifier
    if identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      identifierError = "Username or email is required"
      isValid = false
    }

    // Validate password only if we're using password authentication
    if isUsingPassword && password.isEmpty {
      passwordError = "Password is required"
      isValid = false
    }

    return isValid
  }
}

#Preview {
  LoginView()
    .environmentObject(AuthManager())
}
