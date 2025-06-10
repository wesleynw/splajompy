import Kingfisher
import PostHog
import SwiftUI

struct SettingsView: View {
  @EnvironmentObject private var authManager: AuthManager
  @State var isShowingSignoutConfirm: Bool = false
  @State var isShowingDeleteAccountConfirm: Bool = false
  @State var isShowingDeleteAccountSheet: Bool = false
  @State var deleteAccountPassword: String = ""
  @State var deleteAccountError: String = ""
  @AppStorage("mindlessMode") private var mindlessMode: Bool = false

  let appVersion =
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
  let buildNumber =
    Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""

  var body: some View {
    VStack {
      List {
        NavigationLink(destination: AppearanceSwitcher()) {
          Label("Appearance", systemImage: "circle.lefthalf.filled")
        }

        NavigationLink(destination: AppIconPickerView()) {
          Label("App Icon", systemImage: "square.grid.2x2")
        }

        Toggle(isOn: $mindlessMode) {
          Label("Mindless Mode", systemImage: "infinity")
        }

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
          Text("This action cannot be undone. All your posts, comments, and data will be permanently deleted.")
        }

        StorageManager()

        Section {
          Link(destination: URL(string: "https://splajompy.com/privacy")!) {
            Label("Privacy Policy", systemImage: "lock.shield")
          }
          Link(destination: URL(string: "https://splajompy.com/tos")!) {
            Label("Terms of Service", systemImage: "doc.text")
          }
        }

        Section {
          HStack {
            Text("Version")
            Spacer()
            Text("\(appVersion) (Build \(buildNumber))")
              .font(.footnote)
              .fontWeight(.bold)
              .foregroundColor(.secondary)
          }
        }
      }
    }
    .navigationTitle("Settings")
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
              let (success, error) = await authManager.deleteAccount(password: deleteAccountPassword)
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
      .presentationDetents([.medium])
      .presentationDragIndicator(.visible)
    }
  }
}

#Preview {
  NavigationStack {
    SettingsView()
  }
}
