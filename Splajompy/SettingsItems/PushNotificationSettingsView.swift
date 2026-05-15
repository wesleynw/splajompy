import SwiftUI

private enum SaveStatus {
  case idle, saving, error
}

struct PushNotificationSettingsView: View {
  @AppStorage("push_notifications_enabled") private var isPushNotificationsEnabled: Bool = false
  @AppStorage("push_pref_comments") private var comments: Bool = false
  @AppStorage("push_pref_mentions") private var mentions: Bool = false
  @AppStorage("push_pref_follows") private var follows: Bool = false

  @State private var saveStatus: SaveStatus = .idle

  private let profileService: ProfileServiceProtocol

  init(profileService: ProfileServiceProtocol = ProfileService()) {
    self.profileService = profileService
  }

  var body: some View {
    List {
      Toggle("Push Notifications", isOn: $isPushNotificationsEnabled)

      if isPushNotificationsEnabled {
        Toggle("Comments", isOn: $comments)
          .onChange(of: comments) { _, _ in savePreferences() }
        Toggle("Mentions", isOn: $mentions)
          .onChange(of: mentions) { _, _ in savePreferences() }
        Toggle("Follows", isOn: $follows)
          .onChange(of: follows) { _, _ in savePreferences() }
      }
    }
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
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
    .onChange(of: isPushNotificationsEnabled) { _, newValue in
      if newValue {
        Task {
          do {
            try await UNUserNotificationCenter.current().requestAuthorization(options: [
              .alert, .badge,
            ])
            UIApplication.shared.registerForRemoteNotifications()
          } catch {
            print("error")
          }
        }
      } else {
        UIApplication.shared.unregisterForRemoteNotifications()
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
    .navigationBarTitleDisplayMode(.inline)
  }

  private func savePreferences() {
    saveStatus = .saving
    let prefs = PushPreferences(comments: comments, mentions: mentions, followers: follows)
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
