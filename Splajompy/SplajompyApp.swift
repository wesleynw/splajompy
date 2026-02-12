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
    NavigationPath(),
  ]

  @State private var authManager = AuthManager.shared
  @State private var postManager = PostStore()
  @AppStorage("appearance_mode") var appearanceMode: String = "Automatic"

  init() {
    initializeOtel()
    initializePostHog()

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
      .environment(authManager)
      .preferredColorScheme(colorScheme)
    }
    #if os(macOS)
      .defaultSize(width: 1250, height: 800)
      .commands {
        CommandGroup(replacing: .appSettings) {
          Button("Settings...") {
            selection = 4
          }
          .keyboardShortcut(",", modifiers: .command)
        }
      }
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
          .navigationDestination(for: SettingsRoute.self) { route in
            settingsRouteDestination(route)
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
          NavigationLink(value: 4) {
            Label("Settings", systemImage: "gearshape")
          }
        }
        .navigationSplitViewColumnWidth(175)
      } detail: {
        NavigationStack(path: $navigationPaths[selection]) {
          Group {
            switch selection {
            case 0:
              MainFeedView(postManager: postManager)
                .toolbar(removing: .title)
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
            case 4:
              SettingsView()
                .postHogScreenView()
            default:
              MainFeedView(postManager: postManager)
                .postHogScreenView()
            }
          }
          .navigationDestination(for: Route.self) { route in
            routeDestination(route)
          }
          .navigationDestination(for: SettingsRoute.self) { route in
            settingsRouteDestination(route)
          }
          .onOpenURL { url in
            handleDeepLink(url)
          }
        }
      }
      .scrollIndicators(.visible)
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
      UserListView(userId: userId, userListVariant: .following)
    case .mutualsList(let userId):
      UserListView(userId: userId, userListVariant: .mutuals)
    }
  }

  @ViewBuilder
  private func settingsRouteDestination(_ route: SettingsRoute) -> some View {
    switch route {
    case .settings:
      SettingsView()
    case .account:
      AccountSettingsView()
    case .appearance:
      AppearanceSwitcher()
    case .appIcon:
      #if os(iOS)
        AppIconPickerView()
      #else
        EmptyView()
      #endif
    case .secretPage:
      SecretPageView()
    case .support:
      RequestSupportView()
    case .about:
      AboutView()
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
      NavigationPath(),
    ]

    selection = 0

    postManager.clearCache()

    #if !DEBUG
      PostHogSDK.shared.reset()
    #endif
  }
}
