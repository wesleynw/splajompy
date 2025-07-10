import Kingfisher
import PostHog
import SwiftUI

struct SettingsView: View {
  @EnvironmentObject private var authManager: AuthManager
  @AppStorage("mindlessMode") private var mindlessMode: Bool = false

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

        Toggle(isOn: $mindlessMode) {
          Label("Mindless Mode", systemImage: "infinity")
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
      #if os(macOS)
        .contentMargins(.horizontal, 20, for: .scrollContent)
        .safeAreaPadding(.horizontal, 20)
      #endif
    }
    .navigationTitle("Settings")
  }
}

#Preview {
  NavigationStack {
    SettingsView()
  }
}
