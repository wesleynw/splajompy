import SwiftUI

struct PushNotificationSettingsView: View {
  @AppStorage("push_notifications_enabled") private var isPushNotificationsEnabled: Bool = false
  var body: some View {
    List {
      Toggle("Push Notifications", isOn: $isPushNotificationsEnabled)
    }
    .onChange(of: isPushNotificationsEnabled) { _, newValue in
      if newValue {
        Task {
          do {
            try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge])
            UIApplication.shared.registerForRemoteNotifications()
          }
          catch {
            print("error")
          }
        }
      } else {
        UIApplication.shared.unregisterForRemoteNotifications()
      }
    }
    .navigationTitle("Notifications")
    .navigationBarTitleDisplayMode(.inline)
  }
}

#Preview {
  NavigationStack {
    PushNotificationSettingsView()
  }
}
