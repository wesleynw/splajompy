import PostHog
import SwiftUI

struct SettingsView: View {
  @EnvironmentObject private var authManager: AuthManager

  let appVersion =
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
  let buildNumber =
    Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""

  var body: some View {
    VStack {
      List {
        NavigationLink(destination: AccountSettingsView()) {
          HStack {
            Label("Account", systemImage: "person.circle")
            Spacer()
            if let user = authManager.getCurrentUser() {
              Text("@\(user.username)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
          }
        }

        NavigationLink(destination: AppearanceSwitcher()) {
          Label("Appearance", systemImage: "circle.lefthalf.filled")
        }

        #if os(iOS)
          NavigationLink(destination: AppIconPickerView()) {
            Label("App Icon", systemImage: "square.grid.2x2")
          }
        #endif

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
          NavigationLink(destination: RequestFeatureView()) {
            Label("Request a feature", systemImage: "lightbulb.max")
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
      #if os(macOS)
        .contentMargins(.horizontal, 20, for: .scrollContent)
        .safeAreaPadding(.horizontal, 20)
      #endif
    }
    .navigationTitle("Settings")
  }
}

#Preview {
  let authManager = AuthManager()
  NavigationStack {
    SettingsView()
      .environmentObject(authManager)
  }
}
