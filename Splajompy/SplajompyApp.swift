import PostHog
import SwiftUI

@main
struct SplajompyApp: App {
  @StateObject private var authManager = AuthManager()
  @StateObject private var feedRefreshManager = FeedRefreshManager()

  init() {
    let posthogApiKey = "phc_sSDHxTCqpjwoSDSOQiNAAgmybjEakfePBsaNHWaWy74"

    let config = PostHogConfig(apiKey: posthogApiKey)
    config.captureScreenViews = false
    PostHogSDK.shared.setup(config)
  }

  var body: some Scene {
    WindowGroup {
      Group {
        if authManager.isAuthenticated {
          TabView {
            HomeView()
              .postHogScreenView()
              .tabItem {
                Label("Home", systemImage: "house")
              }

            SearchView()
              .postHogScreenView()
              .tabItem {
                Label("Search", systemImage: "magnifyingglass")
              }

            NotificationsView()
              .postHogScreenView()
              .tabItem {
                Label("Notifications", systemImage: "bell")
              }

            CurrentProfileView()
              .postHogScreenView()
              .tabItem {
                Label("Profile", systemImage: "person.circle")
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
