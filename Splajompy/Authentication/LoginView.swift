import SwiftUI

struct LoginView: View {
  @Binding var isPresenting: Bool
  @Environment(\.dismiss) var dismiss

  @State private var identifier = ""
  @State private var hasRequestedCode: Bool = false
  @State private var showError: Bool = false

  @FocusState private var isIdentifierFieldFocused: Bool

  @EnvironmentObject private var authManager: AuthManager

  var body: some View {
    NavigationStack {
      VStack {
        VStack(alignment: .leading, spacing: 5) {
          TextField(
            "Username or Email",
            text: Binding(
              get: { identifier },
              set: { identifier = $0.lowercased() }
            )
          )
          .padding(12)
          .background(
            RoundedRectangle(cornerRadius: 8)
              .stroke(
                isIdentifierFieldFocused
                  ? Color.primary : Color.gray.opacity(0.75),
                lineWidth: 2
              )
          )
          .cornerRadius(8)
          .textContentType(.username)
          #if os(iOS)
            .autocorrectionDisabled()
          #endif
          .focused($isIdentifierFieldFocused)
          .onAppear { isIdentifierFieldFocused = true }
        }
        .padding(.bottom, 10)

        Spacer()

        Button(action: {
          Task {
            let success = await authManager.requestOneTimeCode(for: identifier)
            if success {
              hasRequestedCode = true
            } else {
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

        NavigationLink {
          CredentialedLoginView(
            isPresenting: $isPresenting,
            identifier: $identifier
          )
        } label: {
          HStack {
            Spacer()
            Text("Log in with password")
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
      .navigationDestination(isPresented: $hasRequestedCode) {
        OneTimeCodeView(identifier: identifier, isPresenting: $isPresenting)
          .environmentObject(authManager)
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

#Preview {
  @Previewable @State var isPresenting = true

  return LoginView(isPresenting: $isPresenting)
    .environmentObject(AuthManager())
}
