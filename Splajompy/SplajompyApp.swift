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
  @StateObject private var postManager = PostManager()
  @AppStorage("appearance_mode") var appearanceMode: String = "Automatic"

  init() {
    let posthogApiKey = "phc_sSDHxTCqpjwoSDSOQiNAAgmybjEakfePBsaNHWaWy74"
    let config = PostHogConfig(apiKey: posthogApiKey)
    config.captureScreenViews = false
    PostHogSDK.shared.setup(config)
  }

  var body: some Scene {
    WindowGroup {
      mainContentView
        .onReceive(NotificationCenter.default.publisher(for: .userDidSignOut)) { _ in
          handleUserSignOut()
        }
        .environmentObject(authManager)
        .preferredColorScheme(colorScheme)
    }
    #if os(macOS)
      .defaultSize(width: 1200, height: 800)
      .windowResizability(.contentSize)
    #endif
  }

  @ViewBuilder
  private var mainContentView: some View {
    if authManager.isAuthenticated {
      authenticatedView
    } else {
      SplashScreenView()
    }
  }

  @ViewBuilder
  private var authenticatedView: some View {
    #if os(iOS)
      iOSTabView
    #else
      macOSSplitView
    #endif
  }

  @ViewBuilder
  private var iOSTabView: some View {
    TabView(selection: $selection) {
      NavigationStack(path: $navigationPaths[0]) {
        HomeView(postManager: postManager)
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
        CurrentProfileView(postManager: postManager)
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
  }

  @ViewBuilder
  private var macOSSplitView: some View {
    NavigationSplitView {
      sidebarList
    } detail: {
      detailView
    }
    .onOpenURL { url in
      handleDeepLink(url)
    }
  }

  private var sidebarList: some View {
    List {
      Button(action: { selection = 0 }) {
        Label("Home", systemImage: "house")
      }
      .foregroundColor(selection == 0 ? .primary : .secondary)

      Button(action: { selection = 1 }) {
        Label("Notifications", systemImage: "bell")
      }
      .foregroundColor(selection == 1 ? .primary : .secondary)

      Button(action: { selection = 2 }) {
        Label("Search", systemImage: "magnifyingglass")
      }
      .foregroundColor(selection == 2 ? .primary : .secondary)

      Button(action: { selection = 3 }) {
        Label("Profile", systemImage: "person.circle")
      }
      .foregroundColor(selection == 3 ? .primary : .secondary)
    }
    .navigationSplitViewColumnWidth(min: 180, ideal: 200)
  }

  private var detailView: some View {
    NavigationStack(path: $navigationPaths[selection]) {
      Group {
        switch selection {
        case 0:
          HomeView(postManager: postManager)
            .postHogScreenView()
        case 1:
          NotificationsView()
            .postHogScreenView()
        case 2:
          SearchView()
            .postHogScreenView()
        case 3:
          CurrentProfileView(postManager: postManager)
            .postHogScreenView()
        default:
          HomeView(postManager: postManager)
            .postHogScreenView()
        }
      }
      .navigationDestination(for: Route.self) { route in
        routeDestination(route)
      }
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
      ProfileView(userId: Int(id)!, username: username, postManager: postManager)
    case .post(let id):
      StandalonePostView(postId: id, postManager: postManager)
    }
  }

  private func handleDeepLink(_ url: URL) {
    if let route = parseDeepLink(url) {
      navigationPaths[selection].append(route)
    }
  }

  private func handleUserSignOut() {
    navigationPaths = [
      NavigationPath(),
      NavigationPath(),
      NavigationPath(),
      NavigationPath(),
    ]

    selection = 0

    postManager.clearCache()
  }
}
