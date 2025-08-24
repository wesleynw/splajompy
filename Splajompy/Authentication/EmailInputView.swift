import SwiftUI

struct EmailInputView: View {
  @Binding var identifier: String
  @Binding var isPresenting: Bool
  @Environment(\.dismiss) var dismiss
  @FocusState private var isFieldFocused: Bool
  @State private var showError: Bool = false
  @State private var errorMessage: String = ""
  @State private var shouldShowCodeView: Bool = false

  @EnvironmentObject private var authManager: AuthManager

  var body: some View {
    VStack(alignment: .leading) {
      TextField("Username or Email", text: $identifier)
        .padding(12)
        .background(
          RoundedRectangle(cornerRadius: 8)
            .stroke(
              isFieldFocused ? Color.primary : Color.gray.opacity(0.75),
              lineWidth: 2
            )
        )
        .cornerRadius(8)
        .textContentType(.username)
        #if os(iOS)
          .autocorrectionDisabled()
        #endif
        .focused($isFieldFocused)
        .onAppear { isFieldFocused = true }

      Spacer()

      VStack(spacing: 12) {
        Button(action: {
          dismiss()
        }) {
          HStack {
            Spacer()
            Text("Use password instead")
              .font(.system(size: 16, weight: .bold))
              .padding()
            Spacer()
          }
          .frame(maxWidth: .infinity)
        }
        .disabled(authManager.isLoading)

        Button(action: {
          Task {
            let success = await authManager.requestOneTimeCode(
              for: identifier.lowercased()
            )
            if success {
              shouldShowCodeView = true
            } else {
              errorMessage =
                "Failed to send code. Try again with a different Username or Email."
              showError = true
            }
          }
        }) {
          ZStack {
            HStack {
              Spacer()
              Text("Continue")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(
                  identifier.isEmpty ? Color.primary.opacity(0.4) : Color.white
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
            identifier.isEmpty
              ? Color.secondary.opacity(0.3) : Color.accentColor
          )
          .cornerRadius(10)
        }
        .disabled(authManager.isLoading || identifier.isEmpty)
      }
      .padding(.bottom, 8)
    }
    .padding()
    .navigationTitle("Sign In")
    .navigationBarBackButtonHidden(true)
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
    .navigationDestination(isPresented: $shouldShowCodeView) {
      OneTimeCodeView(
        identifier: identifier.lowercased(),
        isPresenting: $isPresenting
      )
      .environmentObject(authManager)
    }
    .alert(isPresented: $showError) {
      Alert(
        title: Text("Email Failed"),
        message: Text(errorMessage),
        dismissButton: .default(Text("OK"))
      )
    }
  }
}

#Preview {
  @Previewable @State var isPresenting = true
  @Previewable @State var identifier = ""

  NavigationStack {
    EmailInputView(identifier: $identifier, isPresenting: $isPresenting)
      .environmentObject(AuthManager())
  }
}
