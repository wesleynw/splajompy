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
              FeedContainerView()
            }

            Tab("Notifications", systemImage: "bell") {
              NotificationsView()
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
