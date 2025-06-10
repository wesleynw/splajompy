import SwiftUI

struct CurrentProfileView: View {
  @EnvironmentObject private var authManager: AuthManager
  @EnvironmentObject private var feedRefreshManager: FeedRefreshManager

  var body: some View {
    if let currentUser = authManager.getCurrentUser() {
      ProfileView(
        userId: currentUser.userId,
        username: currentUser.username,
        isOwnProfile: true
      )
      .toolbar {
        NavigationLink(
          destination: SettingsView().environmentObject(authManager)
        ) {
          Image(systemName: "gearshape")
        }
      }
    }
  }
}
