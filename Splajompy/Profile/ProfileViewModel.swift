import Foundation


extension ProfileView {
  @MainActor class ViewModel: ObservableObject {
    private let userId: Int
    private var offset = 0
    
    private var profileService: ProfileServiceProtocol

    @Published var profile: UserProfile?
    @Published var posts = [DetailedPost]()
    @Published var postError = ""
    @Published var isLoadingProfile = true
    @Published var isLoadingFollowButton = false

    init(userId: Int, profileService: ProfileServiceProtocol = ProfileService()) {
      self.userId = userId
      self.profileService = profileService
      loadProfile()
    }

    func loadProfile() {
      Task {
        isLoadingProfile = true

        let result = await profileService.getProfile(userId: userId)

        switch result {
        case .success(let userProfile):
          profile = userProfile
        case .error(let error):
          print("Error fetching user profile: \(error.localizedDescription)")
        }

        isLoadingProfile = false
      }
    }
    
    func updateProfile(name: String, bio: String) {
      Task {
        let result = await profileService.updateProfile(name: name, bio: bio)
        switch result {
        case .success(_):
          profile?.name = name
          profile?.bio = bio
        case .error(_):
          break
        }
      }
    }

    func toggleFollowing() {
      guard let profile = self.profile else { return }

      Task {
        isLoadingFollowButton = true

        let result = await profileService.toggleFollowing(
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
