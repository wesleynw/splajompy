import PostHog
import SwiftUI

struct AccountSettingsView: View {
  @EnvironmentObject private var authManager: AuthManager
  @State var isShowingSignoutConfirm: Bool = false
  @State var isShowingDeleteAccountConfirm: Bool = false
  @State var isShowingDeleteAccountSheet: Bool = false
  @State var deleteAccountPassword: String = ""
  @State var deleteAccountError: String = ""

  var body: some View {
    List {
      Section("Account Information") {
        if let user = authManager.getCurrentUser() {
          HStack {
            Text("Email")
              .foregroundColor(.secondary)
            Spacer()
            Text(user.email)
              .fontWeight(.medium)
          }

          HStack {
            Text("Joined")
              .foregroundColor(.secondary)
            Spacer()
            Text(formatDate(user.createdAt))
              .fontWeight(.medium)
          }
        }
      }

      Section {
        Button(action: { isShowingSignoutConfirm = true }) {
          Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
        }
        .listStyle(.plain)
        .confirmationDialog(
          "Are you sure you'd like to sign out?",
          isPresented: $isShowingSignoutConfirm
        ) {
          Button("Sign Out", role: .destructive) {
            PostHogSDK.shared.reset()
            authManager.signOut()
          }
          Button("Cancel", role: .cancel) {}
        }
      }

      Section("Danger Zone") {
        Button(action: { isShowingDeleteAccountConfirm = true }) {
          Label("Delete Account", systemImage: "trash")
            .foregroundColor(.red)
        }
        .confirmationDialog(
          "Are you sure you want to delete your account?",
          isPresented: $isShowingDeleteAccountConfirm
        ) {
          Button("Delete Account", role: .destructive) {
            deleteAccountPassword = ""
            deleteAccountError = ""
            isShowingDeleteAccountSheet = true
          }
          Button("Cancel", role: .cancel) {}
        } message: {
          Text(
            "This action cannot be undone. All your posts, comments, and data will be permanently deleted."
          )
        }
      }
    }
    .navigationTitle("Account")
    .navigationBarTitleDisplayMode(.inline)
    .sheet(isPresented: $isShowingDeleteAccountSheet) {
      VStack(spacing: 24) {
        VStack(spacing: 16) {
          Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(size: 50))
            .foregroundColor(.red)

          Text("Delete Account")
            .font(.title2)
            .fontWeight(.bold)

          Text("Enter your password to confirm account deletion. This action cannot be undone.")
            .font(.body)
            .multilineTextAlignment(.center)
            .foregroundColor(.secondary)
        }

        VStack(alignment: .leading, spacing: 8) {
          SecureField("Password", text: $deleteAccountPassword)
            .padding(12)
            .background(
              RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.75), lineWidth: 1)
            )
            .textContentType(.password)
            .autocapitalization(.none)
            .autocorrectionDisabled()

          if !deleteAccountError.isEmpty {
            Text(deleteAccountError)
              .font(.caption)
              .foregroundColor(.red)
          }
        }

        Spacer()

        VStack(spacing: 12) {
          Button(action: {
            Task {
              let (success, error) = await authManager.deleteAccount(
                password: deleteAccountPassword)
              if !success {
                deleteAccountError = error
              } else {
                isShowingDeleteAccountSheet = false
              }
            }
          }) {
            HStack {
              if authManager.isLoading {
                ProgressView()
                  .progressViewStyle(CircularProgressViewStyle(tint: .white))
                  .scaleEffect(0.8)
              }
              Text("Delete Account")
                .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red)
            .foregroundColor(.white)
            .containerShape(RoundedRectangle(cornerRadius: 10))
          }
          .disabled(deleteAccountPassword.isEmpty || authManager.isLoading)

          Button("Cancel") {
            isShowingDeleteAccountSheet = false
            deleteAccountPassword = ""
            deleteAccountError = ""
          }
          .frame(maxWidth: .infinity)
          .padding()
          .background(Color(.systemGray6))
          .containerShape(RoundedRectangle(cornerRadius: 10))
        }
      }
      .padding(24)
    }
  }

  private func formatDate(_ date: Date) -> String {
    let outputFormatter = DateFormatter()
    outputFormatter.dateStyle = .medium
    return outputFormatter.string(from: date)
  }
}

#Preview {
  NavigationStack {
    AccountSettingsView()
      .environmentObject(AuthManager.shared)
  }
}
