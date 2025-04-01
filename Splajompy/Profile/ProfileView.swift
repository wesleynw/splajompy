import SwiftUI

struct ProfileView: View {
  @StateObject private var viewModel: ViewModel
  @EnvironmentObject private var authManager: AuthManager

  let userId: Int
  let isOwnProfile: Bool

  init(userId: Int, isOwnProfile: Bool) {
    self.userId = userId
    self.isOwnProfile = isOwnProfile
    _viewModel = StateObject(wrappedValue: ViewModel(userId: userId))
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 12) {
        if viewModel.isLoadingProfile {
          ProgressView()
            .scaleEffect(1.5)
            .padding()
        }
        if let user = viewModel.profile {
          VStack(alignment: .leading, spacing: 4) {
            if !user.name.isEmpty {
              Text(user.name)
                .font(.title2)
                .fontWeight(.black)
                .lineLimit(1)
            }

            HStack {
              Spacer()

              if isOwnProfile {
                Button("Sign Out") { authManager.signOut() }
                  .buttonStyle(.bordered)
              } else {
                // TODO this is bad
                Button(viewModel.profile?.isFollowing ?? false ? "Unfollow" : "Follow") {
                  // Toggle follow status
                  // viewModel.toggle()
                }
                .buttonStyle(.bordered)
              }
            }

            if user.isFollower {
              Text("Follows You")
                .fontWeight(.bold)
                .foregroundColor(Color.gray.opacity(0.4))
            }

            if !user.bio.isEmpty {
              Text(user.bio)
                .padding(.vertical, 10)
                .fixedSize(horizontal: false, vertical: true)
            }
          }

          VStack {
            FeedView(feedType: .profile, userId: self.userId)
              .padding(.horizontal, -16)  // Remove horizontal padding from posts
          }
        } else if !viewModel.isLoadingProfile {
          Text("This user doesn't exist.")
            .font(.title)
            .fontWeight(.black)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 40)
        }
      }
      .padding(.top, 16)
      .padding(.horizontal, 16)
    }
    .background(Color(UIColor.systemBackground))
    .overlay(
      Rectangle()
        .frame(height: 1)
        .foregroundColor(Color.gray.opacity(0.2)),
      alignment: .top
    )
    .navigationTitle(viewModel.profile?.username != nil ? "@" + viewModel.profile!.username : "")
  }
}

struct ProfileView_Previews: PreviewProvider {
  static var previews: some View {
    ProfileView(userId: 1, isOwnProfile: false)
  }
}
