import SwiftUI

struct ProfileView: View {
  let username: String
  let userId: Int

  @State private var isShowingProfileEditor: Bool = false
  @StateObject private var viewModel: ViewModel

  @EnvironmentObject private var authManager: AuthManager
  @EnvironmentObject private var feedRefreshManager: FeedRefreshManager

  private var isOwnProfile: Bool {
    authManager.getCurrentUser().userId == userId
  }

  init(userId: Int, username: String) {
    self.userId = userId
    self.username = username
    _viewModel = StateObject(wrappedValue: ViewModel(userId: userId))
  }

  init(userId: Int, username: String, viewModel: ViewModel) {
    self.userId = userId
    self.username = username
    _viewModel = StateObject(wrappedValue: viewModel)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      if viewModel.isLoadingProfile {
        ProgressView()
          .scaleEffect(1.5)
          .padding()
      }
      if let user = viewModel.profile {
        FeedView(feedType: .profile, userId: self.userId) {
          profileHeader(user: user)
        }
        .environmentObject(feedRefreshManager)
        .padding(.horizontal, -16)
      } else if !viewModel.isLoadingProfile {
        Text("This user doesn't exist.")
          .font(.title3)
          .fontWeight(.bold)
          .padding(.top, 40)
      }
    }
    .sheet(isPresented: $isShowingProfileEditor) {
      ProfileEditorView(viewModel: viewModel)
    }
    .padding(.horizontal, 16)
    .navigationTitle("@" + self.username)
  }

  private func profileHeader(user: UserProfile) -> some View {
    VStack(alignment: .leading) {
      if !user.name.isEmpty {
        Text(user.name)
          .font(.title2)
          .fontWeight(.black)
          .lineLimit(1)
      }

      if !user.bio.isEmpty {
        Text(user.bio)
          .padding(.vertical, 10)
      }

      if let isFollowing = viewModel.profile?.isFollowing, !isOwnProfile {
        // this is unnecessarily verbose because you can't apply conditional styling to buttons i guess??
        if isFollowing {
          Button(action: viewModel.toggleFollowing) {
            if viewModel.isLoadingFollowButton {
              ProgressView()
                .frame(maxWidth: .infinity)
            } else {
              Text("Unfollow")
                .frame(maxWidth: .infinity)
            }
          }
          .buttonStyle(.bordered)
        } else {
          Button(action: viewModel.toggleFollowing) {
            if viewModel.isLoadingFollowButton {
              ProgressView()
                .frame(maxWidth: .infinity)
            } else {
              Text("Follow")
                .frame(maxWidth: .infinity)
            }
          }
          .buttonStyle(.borderedProminent)
        }
      } else if isOwnProfile {
        Button(action: { isShowingProfileEditor = true }) {
          Text("Edit Profile")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
      }
      if user.isFollower && !isOwnProfile {
        Text("Follows You")
          .fontWeight(.bold)
          .foregroundColor(Color.gray.opacity(0.4))
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
  }
}

#Preview {
  let mockViewModel = ProfileView.ViewModel(
    userId: 1,
    profileService: MockProfileService()
  )

  let feedRefreshManager = FeedRefreshManager()
  let authManager = AuthManager()

  ProfileView(userId: 1, username: "wesley", viewModel: mockViewModel)
    .environmentObject(feedRefreshManager)
    .environmentObject(authManager)
}
