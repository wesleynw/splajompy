import PostHog
import SwiftUI

@main
struct SplajompyApp: App {
  @State private var selection: Int = 0
  @State private var navigationPaths = [
    NavigationPath(),
    NavigationPath(),
    NavigationPath(),
    NavigationPath(),
  ]
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
          TabView(selection: $selection) {
            NavigationStack(path: $navigationPaths[0]) {
              HomeView()
                .postHogScreenView()
            }
            .tabItem {
              Label("Home", systemImage: "house")
            }

            NavigationStack(path: $navigationPaths[1]) {
              NotificationsView()
                .postHogScreenView()
            }
            .tabItem {
              Label("Notifications", systemImage: "bell")
            }

            NavigationStack(path: $navigationPaths[2]) {
              SearchView()
                .postHogScreenView()
            }
            .tabItem {
              Label("Search", systemImage: "magnifyingglass")
            }

            NavigationStack(path: $navigationPaths[2]) {
              CurrentProfileView()
                .postHogScreenView()
            }
            .tabItem {
              Label("Profile", systemImage: "person.circle")
            }
          }
          .navigationDestination(for: Route.self) { route in
            switch route {
            case .profile(let id, let username):
              ProfileView(userId: Int(id)!, username: username)
            case .post(let id):
              StandalonePostView(postId: id)
            }
          }
          .onOpenURL { url in
            handleDeepLink(url)
          }
        } else {
          SplashScreenView()
        }
      }
      .environmentObject(feedRefreshManager)
      .environmentObject(authManager)
    }
  }

  private func handleDeepLink(_ url: URL) {
    if let route = parseDeepLink(url) {
      navigationPaths[selection].append(route)
    }
  }
}
