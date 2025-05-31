import Foundation

enum ProfileState {
  case idle
  case loading
  case loaded(UserProfile, [DetailedPost])
  case failed(Error)
}

extension ProfileView {
  @MainActor class ViewModel: ObservableObject {
    private let userId: Int
    private var profileService: ProfileServiceProtocol
    private var postService: PostServiceProtocol
    private var postsOffset = 0
    private let fetchLimit = 10
    private var currentPostsTask: Task<Void, Never>?
    private var currentProfileTask: Task<Void, Never>?

    @Published var state: ProfileState = .idle
    @Published var isLoadingFollowButton = false
    @Published var canLoadMorePosts: Bool = true

    init(
      userId: Int,
      profileService: ProfileServiceProtocol = ProfileService(),
      postService: PostServiceProtocol = PostService()
    ) {
      self.userId = userId
      self.profileService = profileService
      self.postService = postService
    }

    func loadProfile() async {
      currentProfileTask?.cancel()

      currentProfileTask = Task {
        async let profileResult = profileService.getProfile(userId: userId)
        async let postsResult = postService.getPostsForFeed(
          feedType: .profile,
          userId: userId,
          offset: 0,
          limit: fetchLimit
        )

        guard !Task.isCancelled else { return }

        let profile = await profileResult
        let posts = await postsResult

        guard !Task.isCancelled else { return }

        switch (profile, posts) {
        case (.success(let userProfile), .success(let fetchedPosts)):
          postsOffset = fetchedPosts.count
          canLoadMorePosts = fetchedPosts.count >= fetchLimit
          state = .loaded(userProfile, fetchedPosts)
        case (.success(let userProfile), .error(_)):
          state = .loaded(userProfile, [])
        case (.error(let error), _):
          state = .failed(error)
        }
      }

      await currentProfileTask?.value
    }

    func loadPosts(reset: Bool = false) async {
      guard case .loaded(let profile, let existingPosts) = state else { return }

      currentPostsTask?.cancel()

      currentPostsTask = Task {
        if reset {
          postsOffset = 0
        }

        guard !Task.isCancelled else { return }

        let result = await postService.getPostsForFeed(
          feedType: .profile,
          userId: userId,
          offset: postsOffset,
          limit: fetchLimit
        )

        guard !Task.isCancelled else { return }

        switch result {
        case .success(let fetchedPosts):
          let allPosts = reset ? fetchedPosts : existingPosts + fetchedPosts
          state = .loaded(profile, allPosts)
          canLoadMorePosts = fetchedPosts.count >= fetchLimit
          postsOffset += fetchedPosts.count
        case .error(let error):
          state = .failed(error)
        }
      }

      await currentPostsTask?.value
    }

    func toggleLike(on post: DetailedPost) {
      guard case .loaded(let profile, var posts) = state else { return }
      if let index = posts.firstIndex(where: { $0.post.postId == post.post.postId }) {
        posts[index].isLiked.toggle()
        state = .loaded(profile, posts)
        Task {
          let result = await postService.toggleLike(
            postId: post.post.postId,
            isLiked: post.isLiked
          )
          if case .error(let error) = result {
            print("Error toggling like: \(error.localizedDescription)")
            guard case .loaded(let currentProfile, var currentPosts) = state,
              let revertIndex = currentPosts.firstIndex(where: {
                $0.post.postId == post.post.postId
              })
            else { return }
            currentPosts[revertIndex].isLiked.toggle()
            state = .loaded(currentProfile, currentPosts)
          }
        }
      }
    }

    func deletePost(on post: DetailedPost) {
      guard case .loaded(let profile, var posts) = state else { return }
      if let index = posts.firstIndex(where: { $0.post.postId == post.post.postId }) {
        posts.remove(at: index)
        state = .loaded(profile, posts)
        Task {
          await postService.deletePost(postId: post.post.postId)
        }
      }
    }

    func updateProfile(name: String, bio: String) {
      Task {
        let result = await profileService.updateProfile(name: name, bio: bio)
        switch result {
        case .success(_):
          if case .loaded(var profile, let posts) = state {
            profile.name = name
            profile.bio = bio
            state = .loaded(profile, posts)
          }
        case .error(_):
          break
        }
      }
    }

    func toggleFollowing() {
      guard case .loaded(let profile, let posts) = state else { return }
      Task {
        isLoadingFollowButton = true
        let result = await profileService.toggleFollowing(
          userId: userId,
          isFollowing: profile.isFollowing
        )
        if case .error(let error) = result {
          print("Error toggling following status: \(error.localizedDescription)")
        } else {
          var updatedProfile = profile
          updatedProfile.isFollowing.toggle()
          state = .loaded(updatedProfile, posts)
        }
        isLoadingFollowButton = false
      }
    }
  }
}
