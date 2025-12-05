import SwiftUI

struct CredentialedLoginView: View {
  @Binding var isPresenting: Bool
  @Environment(\.dismiss) var dismiss

  @State private var identifier: String = ""
  @State private var password = ""
  @State private var hasRequestedCode: Bool = false
  @State private var shouldShowEmailView: Bool = false

  init(isPresenting: Binding<Bool>) {
    self._isPresenting = isPresenting
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
          TextField("Username or Email", text: $identifier)
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
            .onAppear {
              if identifier.isEmpty {
                isIdentifierFieldFocused = true
              } else {
                isPasswordFieldFocused = true
              }
            }
        }
        .padding(.bottom, 10)

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
        }
      }
      .frame(maxHeight: .infinity, alignment: .topLeading)
      .safeAreaInset(edge: .bottom) {
        VStack {
          Button(action: {
            shouldShowEmailView = true
          }) {
            HStack {
              Spacer()
              Text("Email me a code instead")
                .font(.system(size: 16, weight: .bold))
                .padding()
              Spacer()
            }
            .frame(maxWidth: .infinity)
          }
          .disabled(authManager.isLoading)

          AsyncActionButton(
            title: "Continue",
            isLoading: authManager.isLoading,
            isDisabled: authManager.isLoading || password.isEmpty
              || identifier.isEmpty
          ) {
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
        }
      }
      .padding()
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
          #if os(iOS)
            if #available(iOS 26.0, *) {
              Button(role: .close, action: { isPresenting = false })
            } else {
              Button {
                isPresenting = false
              } label: {
                Image(systemName: "xmark.circle.fill")
                  .opacity(0.8)
              }
              .buttonStyle(.plain)
            }
          #else
            CloseButton(onClose: { isPresenting = false })
          #endif
        }
      }
      .navigationDestination(isPresented: $shouldShowEmailView) {
        EmailInputView(identifier: $identifier, isPresenting: $isPresenting)
          .environmentObject(authManager)
      }
      .alert(isPresented: $showError) {
        Alert(
          title: Text("Sign In Failed"),
          message: Text(
            errorMessage.isEmpty
              ? "Try again with a different Username or Email." : errorMessage
          ),
          dismissButton: .default(Text("OK"))
        )
      }
    }
  }
}

#Preview {
  @Previewable @State var isPresenting = true

  CredentialedLoginView(isPresenting: $isPresenting)
    .environmentObject(AuthManager())
}
