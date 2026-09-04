import SwiftUI

struct DeleteAccountView: View {
  var dismiss: () -> Void
  @Environment(AuthManager.self) private var authManager
  @State var deleteAccountPassword: String = ""
  @State var deleteAccountError: String = ""

  var body: some View {
    ScrollView {
      VStack {
        VStack {
          Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(size: 50))
            .foregroundStyle(.red)
            .padding()

          Text("Delete Account")
            .font(.title2)
            .fontWeight(.bold)

          Text(
            "Enter your password to confirm account deletion. This action cannot be undone."
          )
          .font(.body)
          .multilineTextAlignment(.center)
          .foregroundStyle(.secondary)
          .padding()
        }

        VStack(alignment: .leading) {
          SecureField("Password", text: $deleteAccountPassword)
            .padding(12)
            .background(
              RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.75), lineWidth: 1)
            )
            .textContentType(.password)
            #if os(iOS)
              .autocapitalization(.none)
            #endif
            .autocorrectionDisabled()

          if !deleteAccountError.isEmpty {
            Text(deleteAccountError)
              .font(.caption)
              .foregroundStyle(.red)
          }
        }

        Button(action: {
          Task {
            let (success, error) = await authManager.deleteAccount(
              password: deleteAccountPassword
            )
            if !success {
              deleteAccountError = error
            }
          }
        }) {
          HStack {
            if authManager.isLoading {
              ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
            Text("Delete Account")
              .fontWeight(.semibold)
          }
          .frame(maxWidth: .infinity)
          .padding()
          .background(Color.red)
          .foregroundStyle(.white)
          .containerShape(RoundedRectangle(cornerRadius: 10))
        }
        .disabled(deleteAccountPassword.isEmpty || authManager.isLoading)
        .padding(.top)

        Button("Cancel") {
          dismiss()
        }
        .frame(maxWidth: .infinity)
        .padding()
        .containerShape(RoundedRectangle(cornerRadius: 10))
      }
      .padding()
    }
  }
}

#Preview {
  DeleteAccountView(dismiss: {})
    .environment(AuthManager())
}
