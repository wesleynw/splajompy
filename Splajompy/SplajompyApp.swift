import SwiftUI

@main
struct SplajompyApp: App {
  @StateObject private var authManager = AuthManager()
  @StateObject private var feedRefreshManager = FeedRefreshManager()

  var body: some Scene {
    WindowGroup {
      Group {
        if authManager.isAuthenticated {
          TabView {
            Tab("Home", systemImage: "house") {
              FeedContainerView(feedType: .home, title: "Splajompy")
            }

            Tab("Notifications", systemImage: "bell") {
              NotificationsView()
            }

            Tab("All", systemImage: "globe") {
              FeedContainerView(feedType: .all, title: "Splajompy")
            }

            Tab("Profile", systemImage: "person.circle") {
              CurrentProfileView()
            }
          }
        } else {
          SplashScreenView()
        }
      }
      .environmentObject(feedRefreshManager)
      .environmentObject(authManager)
    }
  }

}
