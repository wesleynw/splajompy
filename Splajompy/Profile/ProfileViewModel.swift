import Foundation

extension ProfileView {
  @MainActor class ViewModel: ObservableObject {
    private let userId: Int
    private var offset = 0

    @Published var profile: UserProfile?
    @Published var posts = [DetailedPost]()
    @Published var postError = ""
    @Published var isLoadingProfile = true
    @Published var isLoadingFollowButton = false

    init(userId: Int) {
      self.userId = userId
      loadProfile()
    }

    func loadProfile() {
      Task {
        isLoadingProfile = true

        let result = await ProfileService.getUserProfile(userId: userId)

        switch result {
        case .success(let userProfile):
          profile = userProfile
        case .error(let error):
          print("Error fetching user profile: \(error.localizedDescription)")
        }

        isLoadingProfile = false
      }
    }

    func toggleFollowing() {
      guard let profile = self.profile else { return }

      Task {
        isLoadingFollowButton = true

        let result = await ProfileService.toggleFollowing(
          userId: userId,
          isFollowing: profile.isFollowing
        )

        if case .error(let error) = result {
          print("Error toggling following status: \(error.localizedDescription)")
        } else {
          self.profile?.isFollowing.toggle()

        }

        isLoadingFollowButton = false
      }
    }
  }
}
