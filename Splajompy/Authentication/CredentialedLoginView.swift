import SwiftUI

struct CredentialedLoginView: View {
  @Binding var isPresenting: Bool
  @Environment(\.dismiss) var dismiss

  @State private var identifier: String
  @State private var password = ""
  @State private var hasRequestedCode: Bool = false

  init(isPresenting: Binding<Bool>, identifier: String) {
    self._isPresenting = isPresenting
    self._identifier = State(initialValue: identifier)
  }

  @State var showError: Bool = false
  @State var errorMessage: String = ""

  @FocusState private var isIdentifierFieldFocused: Bool
  @FocusState private var isPasswordFieldFocused: Bool

  @EnvironmentObject private var authManager: AuthManager

  var body: some View {
    NavigationStack {
      VStack {
        VStack(alignment: .leading, spacing: 5) {
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
            .onAppear { isPasswordFieldFocused = true }
        }
        .padding(.bottom, 10)

        Spacer()

        Button(action: {
          Task {
            let (success, err) = await authManager.signInWithPassword(
              identifier: identifier.lowercased(),
              password: password
            )
            if !success {
              errorMessage = err
              showError = true
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
                  password.isEmpty ? Color.primary.opacity(0.4) : Color.white
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
            password.isEmpty ? Color.secondary.opacity(0.3) : Color.accentColor
          )
          .cornerRadius(10)
        }
        .disabled(authManager.isLoading || password.isEmpty)
        .padding(.bottom, 8)

        NavigationLink {
          OneTimeCodeView(identifier: identifier, isPresenting: $isPresenting)
            .environmentObject(authManager)
            .onAppear {
              Task {
                let success = await authManager.requestOneTimeCode(for: identifier)
                if !success {
                  errorMessage =
                    "Failed to send code. Try again with a different Username or Email."
                  showError = true
                }
              }
            }
        } label: {
          HStack {
            Spacer()
            Text("Email me a code instead")
              .font(.system(size: 16, weight: .bold))
              .padding()
            Spacer()
          }
          .background(Color.clear)
          .overlay(
            RoundedRectangle(cornerRadius: 10)
              .stroke(Color.primary, lineWidth: 2)
          )
          .frame(maxWidth: .infinity)
          .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .disabled(authManager.isLoading)
      }
      .padding(.horizontal, 24)
      .padding(.vertical, 32)
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
          CloseButton(onClose: { isPresenting = false })
        }
      }
      .alert(isPresented: $showError) {
        Alert(
          title: Text("Sign In Failed"),
          message: Text(
            errorMessage.isEmpty ? "Try again with a different Username or Email." : errorMessage),
          dismissButton: .default(Text("OK"))
        )
      }
    }
  }
}

#Preview {
  @Previewable @State var isPresenting = true

  CredentialedLoginView(isPresenting: $isPresenting, identifier: "wesley@splajompy.com")
    .environmentObject(AuthManager())
}
