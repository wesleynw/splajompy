import SwiftUI

struct CurrentProfileView: View {
  @EnvironmentObject private var authManager: AuthManager
  @EnvironmentObject private var feedRefreshManager: FeedRefreshManager

  var body: some View {
    let (userId, username) = authManager.getCurrentUser()

    ProfileView(
      userId: userId,
      username: username,
      isOwnProfile: true
    )
  }
}
