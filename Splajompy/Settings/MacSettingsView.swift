#if os(macOS)
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

        NavigationStack {
          PushNotificationSettingsView()
        }
        .tabItem {
          Label("Notifications", systemImage: "bell.badge")
            .labelStyle(.titleAndIcon)
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

  #Preview {
    let authManager = AuthManager()
    MacSettingsView()
      .environment(authManager)
  }
#endif
