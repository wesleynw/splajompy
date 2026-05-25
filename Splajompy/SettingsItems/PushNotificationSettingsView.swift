import PostHog
import SwiftUI
import UserNotifications

private enum SaveStatus {
  case idle, saving, error
}

struct PushNotificationSettingsView: View {
  @Environment(\.scenePhase) private var scenePhase

  @AppStorage("push_notifications_enabled") private
    var isPushNotificationsEnabled: Bool = false
  @AppStorage("push_pref_comments") private var comments: Bool = true
  @AppStorage("push_pref_mentions") private var mentions: Bool = true
  @AppStorage("push_pref_follows") private var follows: Bool = true

  @State private var saveStatus: SaveStatus = .idle
  @State private var notificationAuthorizationStatus: UNAuthorizationStatus?

  private let profileService: ProfileServiceProtocol

  init(profileService: ProfileServiceProtocol = ProfileService()) {
    self.profileService = profileService
  }

  var body: some View {
    List {
      if notificationAuthorizationStatus == .denied {
        VStack {
          Text("Turn on Push Notifications in Settings")

          #if os(iOS)
            Button("Open Settings") {
              Task {
                if let url = URL(
                  string:
                    UIApplication.openNotificationSettingsURLString
                ) {
                  await UIApplication.shared.open(url)
                }
              }
            }
            .buttonStyle(.borderedProminent)
          #endif
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
      } else {
        Toggle("Push Notifications", isOn: $isPushNotificationsEnabled)

        if isPushNotificationsEnabled
          && notificationAuthorizationStatus == .authorized
        {
          Section {
            Toggle("Comments", isOn: $comments)
              .onChange(of: comments) { _, _ in savePreferences() }
            Toggle("Mentions", isOn: $mentions)
              .onChange(of: mentions) { _, _ in savePreferences() }
            Toggle("Follows", isOn: $follows)
              .onChange(of: follows) { _, _ in savePreferences() }
          }
        }
      }
    }
    .toolbar {
      ToolbarItem(
        placement: {
          #if os(iOS)
            .topBarTrailing
          #else
            .primaryAction
          #endif
        }()
      ) {
        switch saveStatus {
        case .saving:
          ProgressView()
            .controlSize(.small)
        case .error:
          Image(systemName: "exclamationmark.triangle")
            .foregroundStyle(.red)
        case .idle:
          EmptyView()
        }
      }
    }
    .task {
      let settings = await UNUserNotificationCenter.current()
        .notificationSettings()
      notificationAuthorizationStatus = settings.authorizationStatus
    }
    .onChange(of: scenePhase) {
      if scenePhase == .active {
        Task {
          let settings = await UNUserNotificationCenter.current()
            .notificationSettings()
          notificationAuthorizationStatus = settings.authorizationStatus
        }
      }
    }
    .onChange(of: isPushNotificationsEnabled) { _, newValue in
      if newValue {
        Task {
          do {
            try await UNUserNotificationCenter.current().requestAuthorization(
              options: [
                .alert, .badge,
              ])
            RemoteNotificationUtilities.registerForRemoteNotifications()
            PostHogSDK.shared.register(["push_notifications_enabled": true])
          } catch {
          }
        }
      } else {
        RemoteNotificationUtilities.unregisterForRemoteNotifications()
        PostHogSDK.shared.register(["push_notifications_enabled": false])
      }
    }
    .task(id: isPushNotificationsEnabled) {
      guard isPushNotificationsEnabled else { return }
      if case .success(let prefs) = await profileService.getPushPreferences() {
        comments = prefs.comments
        mentions = prefs.mentions
        follows = prefs.followers
      }
    }
    .navigationTitle("Notifications")
    #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
    #endif
  }

  private func savePreferences() {
    saveStatus = .saving
    let prefs = PushPreferences(
      comments: comments,
      mentions: mentions,
      followers: follows
    )
    Task {
      let result = await profileService.updatePushPreferences(prefs: prefs)
      withAnimation {
        saveStatus = if case .error = result { .error } else { .idle }
      }
    }
  }
}

#Preview {
  NavigationStack {
    PushNotificationSettingsView(profileService: MockProfileService())
  }
}
