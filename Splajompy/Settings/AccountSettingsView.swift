import PostHog
import SwiftUI

struct AccountSettingsView: View {
  @Environment(AuthManager.self) private var authManager
  @State var isShowingSignoutConfirm: Bool = false
  @State var isShowingDeleteAccountConfirm: Bool = false
  @State var isShowingDeleteAccountSheet: Bool = false

  var body: some View {
    Form {
      accountSections
    }
    .formStyle(.grouped)
    .modify {
      #if os(iOS)
        $0.pageTitle("Account")
      #endif
    }
    .sheet(isPresented: $isShowingDeleteAccountSheet) {
      DeleteAccountView(dismiss: { isShowingDeleteAccountSheet = false })
        .postHogScreenView()
    }
  }

  @ViewBuilder
  private var accountSections: some View {
    Section {
      if let user = authManager.currentUser {
        HStack {
          Text("Email")
            .foregroundStyle(.secondary)
          Spacer()
          Text(user.email)
            .fontWeight(.medium)
        }

        HStack {
          Text("Joined")
            .foregroundStyle(.secondary)
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
      .confirmationDialog(
        "Are you sure you'd like to sign out?",
        isPresented: $isShowingSignoutConfirm
      ) {
        Button("Sign Out", role: .destructive) {
          authManager.signOut()
          PostHogSDK.shared.reset()
        }
        Button("Cancel", role: .cancel) {}
      }
    }

    Section {
      Button(action: { isShowingDeleteAccountConfirm = true }) {
        Label("Delete Account", systemImage: "trash")
          .foregroundStyle(.red)
      }
      .confirmationDialog(
        "Are you sure you want to delete your account?",
        isPresented: $isShowingDeleteAccountConfirm
      ) {
        Button("Delete Account", role: .destructive) {
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

  private func formatDate(_ date: Date) -> String {
    let outputFormatter = DateFormatter()
    outputFormatter.dateStyle = .medium
    return outputFormatter.string(from: date)
  }
}

#Preview {
  let authManager = AuthManager()

  NavigationStack {
    AccountSettingsView()
      .environment(authManager)
  }
}
