import Nuke
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

  @StateObject private var authManager = AuthManager.shared
  private var postManager = PostManager()
  @AppStorage("appearance_mode") var appearanceMode: String = "Automatic"

  init() {
    #if !DEBUG
      let posthogApiKey = "phc_sSDHxTCqpjwoSDSOQiNAAgmybjEakfePBsaNHWaWy74"
      let config = PostHogConfig(apiKey: posthogApiKey)
      config.captureScreenViews = false
      PostHogSDK.shared.setup(config)
    #endif

    var cacheConfig = ImagePipeline.Configuration.withDataCache(
      name: "media-cache",
      sizeLimit: 500 * 1024 * 1024  // 500MB
    )
    cacheConfig.dataCachePolicy = .storeEncodedImages  // cache processed images
    ImagePipeline.shared = ImagePipeline(configuration: cacheConfig)
  }

  var body: some Scene {
    WindowGroup {
      Group {
        if authManager.isAuthenticated {
          authenticatedView
        } else {
          SplashScreenView()
        }
      }
      .onReceive(NotificationCenter.default.publisher(for: .userDidSignOut)) {
        _ in
        handleUserSignOut()
      }
      .environmentObject(authManager)
      .preferredColorScheme(colorScheme)
    }
    #if os(macOS)
      .defaultSize(width: 1250, height: 800)
    #endif
  }

  @ViewBuilder
  private var authenticatedView: some View {
    #if os(iOS)
      iOSTabView
    #else
      splitView
    #endif
  }

  @ViewBuilder
  private var iOSTabView: some View {
    TabView(selection: $selection) {
      NavigationStack(path: $navigationPaths[0]) {
        MainFeedView(postManager: postManager)
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

      if PostHogSDK.shared.isFeatureEnabled("secret-tab") {
        VStack {
          Image(systemName: "laurel.leading.laurel.trailing")
            .font(.largeTitle)
          Text("This is the secret tab.")
            .font(.title2)
            .fontWeight(.bold)
            .padding()
          Text("Few can see the secret tab.")
            .fontWeight(.bold)
            .padding()

          Text("Please do not discuss the secret tab amongst yourselves.")
            .padding()
        }
        .padding()
        .multilineTextAlignment(.center)
        .tabItem {
          Label("Secret", systemImage: "fossil.shell")
        }
      }

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

  #if os(macOS)
    @ViewBuilder
    private var splitView: some View {
      NavigationSplitView {
        List(selection: $selection) {
          NavigationLink(value: 0) {
            Label("Home", systemImage: "house")
          }
          NavigationLink(value: 1) {
            Label("Notifications", systemImage: "bell")
          }
          NavigationLink(value: 2) {
            Label("Search", systemImage: "magnifyingglass")
          }
          NavigationLink(value: 3) {
            Label("Profile", systemImage: "person.circle")
          }
        }
        .navigationSplitViewColumnWidth(175)
      } detail: {
        NavigationStack(path: $navigationPaths[selection]) {
          Group {
            switch selection {
            case 0:
              MainFeedView(postManager: postManager)
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
              MainFeedView(postManager: postManager)
                .postHogScreenView()
            }
          }
          .navigationDestination(for: Route.self) { route in
            routeDestination(route)
          }
          .onOpenURL { url in
            handleDeepLink(url)
          }
        }
      }
    }
  #endif

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
      ProfileView(
        userId: Int(id)!,
        username: username,
        postManager: postManager
      )
    case .post(let id):
      StandalonePostView(postId: id, postManager: postManager)
    case .followingList(let userId):
      FollowingListView(userId: userId, postManager: postManager)
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
