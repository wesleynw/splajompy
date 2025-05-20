import PostHog
import SwiftUI

@main
struct SplajompyApp: App {
  @StateObject private var authManager = AuthManager()
  @StateObject private var feedRefreshManager = FeedRefreshManager()

  init() {
    let posthogApiKey = "phc_sSDHxTCqpjwoSDSOQiNAAgmybjEakfePBsaNHWaWy74"

    let config = PostHogConfig(apiKey: posthogApiKey)
    PostHogSDK.shared.setup(config)
  }

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
