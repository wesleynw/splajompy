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
    }
    .frame(maxHeight: .infinity, alignment: .topLeading)
    .safeAreaInset(edge: .bottom) {
      VStack {
        Button(action: {
          dismiss()
        }) {
          Text("Use password instead")
            .fontWeight(.bold)
            .font(.body)
            .padding()
            .frame(maxWidth: .infinity)
        }
        .disabled(authManager.isLoading)

        AsyncActionButton(
          title: "Continue",
          isLoading: authManager.isLoading,
          isDisabled: authManager.isLoading || identifier.isEmpty
        ) {
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
        }
      }
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
