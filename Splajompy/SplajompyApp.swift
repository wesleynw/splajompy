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
          if #available(iOS 18, *) {
            TabView {
              Tab("Home", systemImage: "house") {
                HomeView()
                  .postHogScreenView()
              }
              Tab("Notifications", systemImage: "bell") {
                NotificationsView()
                  .postHogScreenView()
              }
              Tab("Profile", systemImage: "person.circle") {
                CurrentProfileView()
                  .postHogScreenView()
              }
              Tab("Search", systemImage: "magnifyingglass", role: .search) {
                SearchView()
                  .postHogScreenView()
              }
            }
          } else {
            TabView {
              HomeView()
                .postHogScreenView()
                .tabItem {
                  Label("Home", systemImage: "house")
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
              SearchView()
                .postHogScreenView()
                .tabItem {
                  Label("Search", systemImage: "magnifyingglass")
                }
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
