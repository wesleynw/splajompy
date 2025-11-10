import PostHog
import SwiftUI

struct SettingsView: View {
  @EnvironmentObject private var authManager: AuthManager

  var body: some View {
    VStack {
      List {
        NavigationLink(destination: AccountSettingsView()) {
          Label("Account", systemImage: "person.circle")
        }

        NavigationLink(destination: AppearanceSwitcher()) {
          Label("Appearance", systemImage: "circle.lefthalf.filled")
        }

        #if os(iOS)
          NavigationLink(destination: AppIconPickerView()) {
            Label("App Icon", systemImage: "square.grid.2x2")
          }
        #endif

        if PostHogSDK.shared.isFeatureEnabled("secret-tab") {
          NavigationLink(destination: SecretPageView()) {
            Label("Secret Page", systemImage: "fossil.shell")
          }
        }

        Section {
          NavigationLink(destination: RequestSupportView()) {
            Label("Support", systemImage: "lifepreserver")
          }
        }

        Section {
          NavigationLink(destination: AboutView()) {
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
      .environmentObject(authManager)
  }
}
