import PostHog
import SwiftUI
import UserNotifications

struct PushNotificationsOnboardingView: View {
  var onComplete: () -> Void
  @Environment(\.scenePhase) private var scenePhase
  @AppStorage("push_notifications_enabled") private
    var isPushNotificationsEnabled: Bool = false

  @AppStorage("push_pref_comments") private var comments: Bool = true
  @AppStorage("push_pref_mentions") private var mentions: Bool = true
  @AppStorage("push_pref_follows") private var follows: Bool = true

  @State private var notificationAuthorizationStatus: UNAuthorizationStatus?

  var body: some View {
    ScrollView {
      VStack {
        VStack(spacing: 6) {
          Text("Listen to us.")
            .font(.title)
            .fontWeight(.bold)

          Text(
            "Let Splajompy bother you with push notications."
          )
          .foregroundStyle(.secondary)
          .padding()
        }
        .multilineTextAlignment(.center)
        .padding()

        if notificationAuthorizationStatus != .authorized
          || !isPushNotificationsEnabled
        {
          Button {
            Task {
              if notificationAuthorizationStatus == .denied {
                if let url = URL(
                  string:
                    UIApplication.openNotificationSettingsURLString
                ) {
                  await UIApplication.shared.open(url)
                }
              } else {
                do {
                  isPushNotificationsEnabled = true
                  try await UNUserNotificationCenter.current()
                    .requestAuthorization(
                      options: [
                        .alert, .badge,
                      ])
                  RemoteNotificationUtilities.registerForRemoteNotifications()
                  PostHogSDK.shared.register([
                    "push_notifications_enabled": true
                  ])
                } catch {
                  PostHogSDK.shared.capture(
                    "push_notifications_failed_registration"
                  )
                }
              }
            }
          } label: {
            Text("Allow Notifications")
              .fontWeight(.semibold)
          }
          .controlSize(.large)
          .modify {
            if #available(iOS 26, *) {
              $0.buttonStyle(.glass)
            } else {
              $0.buttonStyle(.bordered)
            }
          }
          .transition(.opacity)
        }

        if isPushNotificationsEnabled
          && notificationAuthorizationStatus == .authorized
        {
          Group {
            Toggle("Mentions", isOn: $mentions)
              .onChange(of: mentions) {
                RemoteNotificationUtilities.registerForRemoteNotifications()
              }
            Toggle("Comments", isOn: $comments)
              .onChange(of: comments) {
                RemoteNotificationUtilities.registerForRemoteNotifications()
              }
            Toggle("Follows", isOn: $follows)
              .onChange(of: follows) {
                RemoteNotificationUtilities.registerForRemoteNotifications()
              }
          }
          .padding()
          .transition(.opacity)
        }
      }
      .animation(.default, value: notificationAuthorizationStatus)
      .animation(.default, value: isPushNotificationsEnabled)
      .padding()
    }
    .safeAreaInset(edge: .bottom) {
      Button {
        onComplete()
      } label: {
        Text("Save")
          .fontWeight(.black)
          .frame(maxWidth: .infinity)
      }
      .controlSize(.large)
      .modify {
        if #available(iOS 26, *) {
          $0.buttonStyle(.glassProminent)
        } else {
          $0.buttonStyle(.borderedProminent)
        }
      }
    }
    .padding()
    .task {
      let settings = await UNUserNotificationCenter.current()
        .notificationSettings()
      notificationAuthorizationStatus = settings.authorizationStatus
    }
    .onChange(of: notificationAuthorizationStatus) { oldValue, newValue in
      // recently denied, still show when prior setting was denied
      if oldValue != nil && newValue == .denied {
        onComplete()
      }
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
  }
}

#Preview {
  NavigationStack {
    Color.clear
      .sheet(isPresented: .constant(true)) {
        PushNotificationsOnboardingView(
          onComplete: {}
        )
      }
  }
}
