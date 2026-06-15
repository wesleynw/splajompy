import PostHog
import SwiftUI

enum ProfileState {
  case idle
  case loading
  case loaded(DetailedUser, FeedState)
  case failed(String)
}

extension ProfileView {
  @MainActor @Observable class ViewModel {
    private let userId: Int
    private var profileService: ProfileServiceProtocol
    private var lastPostTimestamp: Date?
    private let fetchLimit = 10
    var postManager: PostStore

    var profileState: ProfileState = .idle
    var updateError: String?
    var isLoading: Bool = false
    var isLoadingFollowButton: Bool = false
    var isLoadingBlockButton: Bool = false
    var isLoadingMuteButton: Bool = false
    var canLoadMorePosts: Bool = true
    var isLoadingMorePosts: Bool = false

    init(
      userId: Int,
      postManager: PostStore,
      profileService: ProfileServiceProtocol = ProfileService()
    ) {
      self.userId = userId
      self.postManager = postManager
      self.profileService = profileService
    }

    func loadProfileAndPosts(reset: Bool = false) async {
      // if profile or posts are already loaded, don't reset to loading state when updating
      if reset {
        profileState = .loading
      }

      async let profileResult = profileService.getProfile(userId: userId)
      async let postsResult = postManager.loadFeed(
        feedType: .profile,
        userId: userId,
        beforeTimestamp: nil,
        limit: fetchLimit
      )

      let profile = await profileResult
      let posts = await postsResult

      switch (profile, posts) {
      case (.success(let user), .success(let fetchedPosts)):
        lastPostTimestamp = fetchedPosts.last?.post.createdAt
        canLoadMorePosts = fetchedPosts.count >= fetchLimit
        profileState = .loaded(user, .loaded(fetchedPosts))

      case (.success(let user), .failure(let error)):
        profileState = .loaded(user, .failed(error))

      case (.failure(let error), _):
        profileState = .failed(error.localizedDescription)
      }
    }

    func loadPosts(reset: Bool = false) async {
      guard case .loaded(let user, let currentFeedState) = profileState else {
        return
      }

      if reset {
        lastPostTimestamp = nil
        profileState = .loaded(user, .loading)
      }

      defer {
        isLoadingMorePosts = false
      }

      let result = await postManager.loadFeed(
        feedType: .profile,
        userId: userId,
        beforeTimestamp: lastPostTimestamp,
        limit: fetchLimit
      )

      switch result {
      case .success(let fetchedPosts):
        let existing: [ObservablePost] = {
          if case .loaded(let existingPosts) = currentFeedState {
            return existingPosts
          }
          return []
        }()

        let merged = reset ? fetchedPosts : existing + fetchedPosts
        lastPostTimestamp = fetchedPosts.last?.post.createdAt
        canLoadMorePosts = fetchedPosts.count >= fetchLimit
        profileState = .loaded(user, .loaded(merged))
      case .failure(let error):
        profileState = .loaded(user, .failed(error))
      }
    }

    func toggleLike(on post: ObservablePost) {
      Task {
        await postManager.togglePostLiked(id: post.id)
      }
    }

    func deletePost(on post: ObservablePost) {
      guard case .loaded(let user, let feedState) = profileState,
        case .loaded(let currentPosts) = feedState
      else { return }

      let updated = currentPosts.filter { $0.id != post.id }
      profileState = .loaded(user, .loaded(updated))

      PostHogSDK.shared.capture("post_deleted")
      Task {  // TODO: optimistic update?
        await postManager.deletePost(id: post.id)
      }
    }

    func pinPost(_ post: ObservablePost) {
      Task {
        let success = await postManager.pinPost(id: post.id)
        if success {
          reorderPostsForPin(pinningPost: post)
        }
      }
    }

    func unpinPost(_ post: ObservablePost) {
      Task {
        let success = await postManager.unpinPost()
        if success {
          repositionPostChronologically(post)
        }
      }
    }

    func updateProfile(
      name: String,
      bio: String,
      displayProperties: UserDisplayProperties
    ) async {
      guard case .loaded(let user, let feedState) = profileState else { return }

      let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
      let trimmedBio = bio.trimmingCharacters(in: .whitespacesAndNewlines)

      isLoading = true
      defer { isLoading = false }

      let result = await profileService.updateProfile(
        name: trimmedName,
        bio: trimmedBio,
        displayProperties: displayProperties
      )

      switch result {
      case .success:
        var updatedUser = user
        updatedUser.name = trimmedName
        updatedUser.bio = trimmedBio
        updatedUser.displayProperties = displayProperties
        profileState = .loaded(updatedUser, feedState)

      case .failure(let error):
        updateError = error.localizedDescription
      }
    }

    func toggleFollowing() {
      guard case .loaded(let profile, let feedState) = profileState else {
        return
      }
      Task {
        isLoadingFollowButton = true
        let result = await profileService.toggleFollowing(
          userId: userId,
          isFollowing: profile.isFollowing
        )
        switch result {
        case .success(_):
          PostHogSDK.shared.capture(
            profile.isFollowing ? "user_unfollowed" : "user_followed"
          )
          var updatedProfile = profile
          updatedProfile.isFollowing.toggle()
          profileState = .loaded(updatedProfile, feedState)
        case .failure(let error):
          profileState = .failed(error.localizedDescription)
        }
        isLoadingFollowButton = false
      }
    }

    func toggleBlocking() {
      guard case .loaded(let profile, let feedState) = profileState else {
        return
      }
      Task {
        isLoadingBlockButton = true
        let result = await profileService.toggleBlocking(
          userId: userId,
          isBlocking: profile.isBlocking
        )
        switch result {
        case .success(_):
          var updatedProfile = profile
          updatedProfile.isBlocking.toggle()
          updatedProfile.isFollower = false
          profileState = .loaded(updatedProfile, feedState)
        case .failure(let error):
          profileState = .failed(error.localizedDescription)
        }
        isLoadingBlockButton = false
      }
    }

    func toggleMuting() {
      guard case .loaded(let profile, let feedState) = profileState else {
        return
      }
      Task {
        isLoadingMuteButton = true
        let result = await profileService.toggleMuting(
          userId: userId,
          isMuting: profile.isMuting
        )
        switch result {
        case .success(_):
          var updatedProfile = profile
          updatedProfile.isMuting.toggle()
          profileState = .loaded(updatedProfile, feedState)
        case .failure(let error):
          profileState = .failed(error.localizedDescription)
        }
        isLoadingMuteButton = false
      }
    }

    func handlePostAppear(at index: Int, totalCount: Int) {
      guard case .loaded(_, _) = profileState,
        index >= totalCount - 3,
        canLoadMorePosts,
        !isLoadingMorePosts
      else { return }

      isLoadingMorePosts = true

      Task {
        await loadPosts()
      }
    }

    func reorderPostsForPin(pinningPost: ObservablePost) {
      guard case .loaded(let user, let feedState) = profileState,
        case .loaded(var currentPosts) = feedState
      else { return }

      // if the top post is being unpinned, move it to it's chronological placement
      if let previousPinnedPost = currentPosts.first,
        previousPinnedPost.isPinned
      {
        repositionPostChronologically(previousPinnedPost)
      }

      // move newly pinned post to top
      currentPosts.removeAll { $0.id == pinningPost.id }
      currentPosts.insert(pinningPost, at: 0)

      profileState = .loaded(user, .loaded(currentPosts))
    }

    private func repositionPostChronologically(
      _ post: ObservablePost,
    ) {
      guard case .loaded(let user, let feedState) = profileState,
        case .loaded(var currentPosts) = feedState
      else { return }

      if let insertIndex = currentPosts.firstIndex(where: {
        $0.post.createdAt < post.post.createdAt
      }) {
        currentPosts.removeAll(where: { $0.id == post.id })
        currentPosts.insert(post, at: insertIndex)
      }

      profileState = .loaded(user, .loaded(currentPosts))
    }
  }
}
