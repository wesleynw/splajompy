import PostHog
import SwiftUI

struct SettingsView: View {
  @Environment(AuthManager.self) private var authManager
  @State private var isShowingWrappedView: Bool = false

  var body: some View {
    VStack {
      List {
        NavigationLink(value: SettingsRoute.account) {
          Label("Account", systemImage: "person.circle")
        }

        NavigationLink(value: SettingsRoute.appearance) {
          Label("Appearance", systemImage: "circle.lefthalf.filled")
        }

        #if os(iOS)
          NavigationLink(value: SettingsRoute.appIcon) {
            Label("App Icon", systemImage: "square.grid.2x2")
          }
        #endif

        if PostHogSDK.shared.isFeatureEnabled("push-notifications") {
          NavigationLink(value: SettingsRoute.notifications) {
            Label("Notifications", systemImage: "bell.badge")
          }
        }

        if PostHogSDK.shared.isFeatureEnabled("secret-tab") {
          NavigationLink(value: SettingsRoute.secretPage) {
            Label("Secret Page", systemImage: "fossil.shell")
          }
        }

        Section {
          NavigationLink(value: SettingsRoute.support) {
            Label("Support", systemImage: "lifepreserver")
          }
        } footer: {
          Text(
            "This is your place to request a feature, ask for help, or just leave a note about what you think about Splajompy!"
          )
        }

        Section {
          NavigationLink(value: SettingsRoute.about) {
            Label("About", systemImage: "info.circle")
          }
        }
      }
    }
    .navigationTitle("Settings")
  }
}

#Preview {
  let authManager = AuthManager()
  NavigationStack {
    SettingsView()
      .environment(authManager)
  }
}
