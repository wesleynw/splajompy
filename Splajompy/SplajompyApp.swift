import PostHog
import SwiftUI

@main
struct SplajompyApp: App {
  #if os(iOS)
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
  #else
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
  #endif

  @State private var routingHelper = RoutingHelper.shared
  @State private var selection: Int = 0
  @State private var navigationPaths = [
    NavigationPath(),
    NavigationPath(),
    NavigationPath(),
    NavigationPath(),
    NavigationPath(),
    NavigationPath(),
  ]

  @State private var authManager: AuthManager = AuthManager.shared
  @State private var postStore = PostStore()
  @AppStorage("appearance_mode") var appearanceMode: String = "Automatic"

  init() {
    initializeOtel()
    initializePostHog()
    initializeImageCache()
  }

  var body: some Scene {
    WindowGroup {
      Group {
        if authManager.isAuthenticated {
          authenticatedView
            .environment(postStore)
        } else {
          SplashScreenView()
            .postHogScreenView()
        }
      }
      .modifier(
        NavigateOnNotificationModifier(
          pendingRoute: $routingHelper.pendingRoute,
          selection: $selection,
          navigationPaths: $navigationPaths
        )
      )
      .onReceive(NotificationCenter.default.publisher(for: .userDidSignOut)) {
        _ in
        handleUserSignOut()
      }
      .modifier(SupportedVersionViewModifier())
      .environment(authManager)
      .preferredColorScheme(colorScheme)
    }
    //    .windowToolbarStyle(.unified(showsTitle: false))
    #if os(macOS)
      .defaultSize(width: 1250, height: 800)
    #endif

    #if os(macOS)
      Settings {
        NavigationStack(path: $navigationPaths[4]) {
          SettingsView()
            .postHogScreenView()
            .preferredColorScheme(colorScheme)
            // TODO: consolidate settingsroutes and normal routes
            .navigationDestination(for: SettingsRoute.self) { route in
              settingsRouteDestination(route)
            }
        }
      }
      .environment(authManager)
    #endif
  }

  @ViewBuilder
  private var authenticatedView: some View {
    TabView(selection: $selection) {
      NavigationStack(path: $navigationPaths[0]) {
        FeedView(postManager: postStore)
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
        CurrentProfileView(postManager: postStore)
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
    .modify {
      if #available(iOS 18, *) {
        $0.tabViewStyle(.sidebarAdaptable)
      }
    }
    .onOpenURL { url in
      handleDeepLink(url)
    }
    #if os(iOS)
      .modifier(OnboardingSheetViewModifier())
    #endif
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
      if let userId = Int(id) {
        ProfileView(
          userId: userId,
          username: username,
          postManager: postStore
        )
        .postHogScreenView()
      } else {
        EmptyView()
      }
    case .post(let id):
      StandalonePostView(postId: id, postManager: postStore)
        .postHogScreenView()
    case .followingList(let userId):
      UserListView(identifier: userId, userListVariant: .following)
        .postHogScreenView()
    case .mutualsList(let userId):
      UserListView(identifier: userId, userListVariant: .mutuals)
        .postHogScreenView()
    case .notificationActorsList(let notificationId, let postId):
      UserListView(
        identifier: notificationId,
        userListVariant: .notification,
        postId: postId
      )
      .postHogScreenView()
    }
  }

  @ViewBuilder
  private func settingsRouteDestination(_ route: SettingsRoute) -> some View {
    switch route {
    case .settings:
      SettingsView()
        .postHogScreenView()
    case .account:
      AccountSettingsView()
        .postHogScreenView()
    case .appearance:
      AppearanceSwitcher()
        .postHogScreenView()
    case .appIcon:
      #if os(iOS)
        AppIconPickerView()
          .postHogScreenView()
      #else
        EmptyView()
      #endif
    case .secretPage:
      SecretPageView()
        .postHogScreenView()
    case .support:
      RequestSupportView()
        .postHogScreenView()
    case .about:
      AboutView()
        .postHogScreenView()
    case .notifications:
      PushNotificationSettingsView()
        .postHogScreenView()
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
    postStore.clearCache()
    PostHogSDK.shared.reset()
  }
}
