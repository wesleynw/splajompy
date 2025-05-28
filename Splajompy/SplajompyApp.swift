import PostHog
import SwiftUI

@main
struct SplajompyApp: App {
  @StateObject private var authManager = AuthManager()
  @StateObject private var feedRefreshManager = FeedRefreshManager()
  @State private var selectedTab = 0

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
          ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
              HomeView()
                .postHogScreenView()
                .tag(0)

              SearchView()
                .postHogScreenView()
                .tag(1)

              NotificationsView()
                .postHogScreenView()
                .tag(2)

              CurrentProfileView()
                .postHogScreenView()
                .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            CustomTabBar(selectedIndex: $selectedTab)
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
