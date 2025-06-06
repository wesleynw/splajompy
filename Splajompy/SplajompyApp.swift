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
  @AppStorage("appearance_mode") var appearanceMode: String = "Automatic"

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
                .navigationDestination(for: Route.self) { route in
                  routeDestination(route)
                }
            }
            .tabItem {
              Label("Home", systemImage: "house")
            }
            .tag(0)

            NavigationStack(path: $navigationPaths[1]) {
              NotificationsView()
                .postHogScreenView()
                .navigationDestination(for: Route.self) { route in
                  routeDestination(route)
                }
            }
            .tabItem {
              Label("Notifications", systemImage: "bell")
            }
            .tag(1)

            NavigationStack(path: $navigationPaths[2]) {
              SearchView()
                .postHogScreenView()
                .navigationDestination(for: Route.self) { route in
                  routeDestination(route)
                }
            }
            .tabItem {
              Label("Search", systemImage: "magnifyingglass")
            }
            .tag(2)

            NavigationStack(path: $navigationPaths[3]) {
              CurrentProfileView()
                .postHogScreenView()
                .navigationDestination(for: Route.self) { route in
                  routeDestination(route)
                }
            }
            .tabItem {
              Label("Profile", systemImage: "person.circle")
            }
            .tag(3)
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
      .preferredColorScheme(colorScheme)
    }
  }

  private var colorScheme: ColorScheme? {
    switch appearanceMode {
    case "Light":
      return .light
    case "Dark":
      return .dark
    default:
      return nil
    }
  }

  @ViewBuilder
  private func routeDestination(_ route: Route) -> some View {
    switch route {
    case .profile(let id, let username):
      ProfileView(userId: Int(id)!, username: username)
    case .post(let id):
      StandalonePostView(postId: id)
    }
  }

  private func handleDeepLink(_ url: URL) {
    if let route = parseDeepLink(url) {
      navigationPaths[selection].append(route)
    }
  }
}
