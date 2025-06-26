import SwiftUI

struct CredentialedLoginView: View {
  @Binding var isPresenting: Bool
  @Environment(\.dismiss) var dismiss

  @Binding var identifier: String
  @State private var password = ""

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
                  isIdentifierFieldFocused ? Color.primary : Color.gray.opacity(0.75),
                  lineWidth: 2
                )
            )
            .cornerRadius(8)
            .textContentType(.username)
            .autocapitalization(.none)
            .autocorrectionDisabled()
            .focused($isIdentifierFieldFocused)
            .onAppear { isIdentifierFieldFocused = true }
            .padding(.bottom, 10)

          SecureField("Password", text: $password)
            .padding(12)
            .background(
              RoundedRectangle(cornerRadius: 8)
                .stroke(
                  isPasswordFieldFocused ? Color.primary : Color.gray.opacity(0.75),
                  lineWidth: 2
                )
            )
            .cornerRadius(8)
            .textContentType(.password)
            .autocapitalization(.none)
            .autocorrectionDisabled()
            .focused($isPasswordFieldFocused)
        }
        .padding(.bottom, 10)

        Spacer()

        Button(action: {
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
        }
        ) {
          ZStack {
            HStack {
              Spacer()
              Text("Continue")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(
                  identifier.isEmpty ? Color.white.opacity(0.4) : Color.white
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
            identifier.isEmpty ? Color.gray.opacity(0.3) : Color.accentColor
          )
          .cornerRadius(10)
        }
        .disabled(authManager.isLoading || identifier.isEmpty)
        .padding(.bottom, 8)

        Button {
          dismiss()
        } label: {
          HStack {
            Spacer()
            Text("Log in with email")
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
      }
      .padding(.horizontal, 24)
      .padding(.vertical, 32)
      .navigationTitle("Sign In")
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
      .alert(isPresented: $showError) {
        Alert(
          title: Text("Sign In Failed"),
          message: Text("Try again with a different Username or Email."),
          dismissButton: .default(Text("OK"))
        )
      }
    }
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
