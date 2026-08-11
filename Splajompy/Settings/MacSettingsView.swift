#if os(macOS)
  import PostHog
  import SwiftUI

  struct MacSettingsView: View {
    var body: some View {
      TabView {
        NavigationStack {
          AccountSettingsView()
        }
        .tabItem {
          Label("Account", systemImage: "person.crop.circle")
            .labelStyle(.titleAndIcon)
        }

        NavigationStack {
          AppearanceSwitcher()
        }
        .tabItem {
          Label("Appearance", systemImage: "circle.lefthalf.filled")
            .labelStyle(.titleAndIcon)
        }

        if PostHogSDK.shared.isFeatureEnabled("push-notifications") {
          NavigationStack {
            PushNotificationSettingsView()
          }
          .tabItem {
            Label("Notifications", systemImage: "bell.badge")
              .labelStyle(.titleAndIcon)
          }
        }

        NavigationStack {
          RequestSupportView()
        }
        .tabItem {
          Label("Support", systemImage: "lifepreserver")
            .labelStyle(.titleAndIcon)
        }

        NavigationStack {
          AboutView()
        }
        .tabItem {
          Label("About", systemImage: "info.circle")
            .labelStyle(.titleAndIcon)
        }

        if PostHogSDK.shared.isFeatureEnabled("statistics-page") {
          NavigationStack {
            StatisticsView()
          }
          .tabItem {
            Label("Statistics", systemImage: "chart.xyaxis.line")
              .labelStyle(.titleAndIcon)
          }
        }
      }
    }
  }

  #Preview {
    let authManager = AuthManager()
    MacSettingsView()
      .environment(authManager)
  }
#endif
