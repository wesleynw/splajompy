import Foundation
import SwiftUI

enum ProfileState {
  case idle
  case loading
  case loaded(UserProfile)
  case failed(String)
}

enum PostsState {
  case idle
  case loading
  case loaded([Int])
  case failed(String)
}

extension ProfileView {
  @MainActor class ViewModel: ObservableObject {
    private let userId: Int
    private var profileService: ProfileServiceProtocol
    private var lastPostTimestamp: Date?
    private let fetchLimit = 10
    @ObservedObject var postManager: PostManager

    @Published var profileState: ProfileState = .idle
    @Published var postsState: PostsState = .idle
    @Published var isLoading: Bool = false
    @Published var isLoadingFollowButton: Bool = false
    @Published var isLoadingBlockButton: Bool = false
    @Published var isLoadingMuteButton: Bool = false
    @Published var canLoadMorePosts: Bool = true
    @Published var isLoadingMorePosts: Bool = false

    init(
      userId: Int,
      postManager: PostManager,
      profileService: ProfileServiceProtocol = ProfileService()
    ) {
      self.userId = userId
      self.postManager = postManager
      self.profileService = profileService
    }

    func loadProfileAndPosts() async {
      // don't reload if we already have both profile and posts data
      if case .loaded(_) = profileState, case .loaded(_) = postsState {
        return
      }

      profileState = .loading
      postsState = .loading

      async let profileResult = profileService.getProfile(userId: userId)
      async let postsResult = postManager.loadFeed(
        feedType: .profile,
        userId: userId,
        beforeTimestamp: nil,
        limit: fetchLimit
      )

      let profile = await profileResult
      let posts = await postsResult

      switch profile {
      case .success(let userProfile):
        profileState = .loaded(userProfile)
      case .error(let error):
        profileState = .failed(error.localizedDescription)
      }

      switch posts {
      case .success(let fetchedPosts):
        postManager.cachePosts(fetchedPosts)
        let postIds = fetchedPosts.map { $0.id }

        // update cursor timestamp to the oldest post in the batch
        if let oldestPost = fetchedPosts.last {
          lastPostTimestamp = oldestPost.post.createdAt
        }

        canLoadMorePosts = fetchedPosts.count >= fetchLimit
        postsState = .loaded(postIds)
      case .error(let error):
        postsState = .failed(error.localizedDescription)
      }
    }

    func loadPosts(reset: Bool = false) async {
      guard case .loaded(_) = profileState else { return }

      if reset {
        lastPostTimestamp = nil
      } else {
        guard canLoadMorePosts else { return }
        guard case .loaded(_) = postsState else { return }
      }

      defer {
        if !reset {
          isLoadingMorePosts = false
        }
      }

      let result = await postManager.loadFeed(
        feedType: .profile,
        userId: userId,
        beforeTimestamp: lastPostTimestamp,
        limit: fetchLimit
      )

      switch result {
      case .success(let fetchedPosts):
        let finalPostIds: [Int]
        if reset {
          finalPostIds = fetchedPosts.map { $0.id }
        } else {
          if case .loaded(let currentIds) = postsState {
            finalPostIds = currentIds + fetchedPosts.map { $0.id }
          } else {
            finalPostIds = fetchedPosts.map { $0.id }
          }
        }

        // update cursor timestamp to the oldest post in the batch
        if let oldestPost = fetchedPosts.last {
          lastPostTimestamp = oldestPost.post.createdAt
        }

        postsState = .loaded(finalPostIds)
        canLoadMorePosts = fetchedPosts.count >= fetchLimit
      case .error(let error):
        postsState = .failed(error.localizedDescription)
      }
    }

    func toggleLike(on post: DetailedPost) {
      Task {
        await postManager.likePost(id: post.id)
      }
    }

    func deletePost(on post: DetailedPost) {
      guard case .loaded(_) = profileState else { return }
      if case .loaded(let currentIds) = postsState,
        let index = currentIds.firstIndex(of: post.id)
      {
        var updatedIds = currentIds
        updatedIds.remove(at: index)
        postsState = .loaded(updatedIds)
        Task {
          await postManager.deletePost(id: post.id)
        }
      }
    }

    func pinPost(_ post: DetailedPost) {
      Task {
        let success = await postManager.pinPost(id: post.id)
        if success {
          reorderPostsForPin(pinnedPostId: post.id)
        }
      }
    }

    func unpinPost(_ post: DetailedPost) {
      Task {
        let success = await postManager.unpinPost()
        if success {
          reorderPostsForUnpin(unpinnedPostId: post.id)
        }
      }
    }

    func updateProfile(name: String, bio: String) {
      isLoading = true
      defer {
        isLoading = false
      }

      Task {
        let result = await profileService.updateProfile(
          name: name.trimmingCharacters(in: .whitespacesAndNewlines),
          bio: bio.trimmingCharacters(in: .whitespacesAndNewlines))
        switch result {
        case .success(_):
          if case .loaded(var profile) = profileState {
            profile.name = name
            profile.bio = bio
            profileState = .loaded(profile)
          }
        case .error(let error):
          profileState = .failed(error.localizedDescription)
        }
      }
    }

    func toggleFollowing() {
      guard case .loaded(let profile) = profileState else { return }
      Task {
        isLoadingFollowButton = true
        let result = await profileService.toggleFollowing(
          userId: userId,
          isFollowing: profile.isFollowing
        )
        switch result {
        case .success(_):
          var updatedProfile = profile
          updatedProfile.isFollowing.toggle()
          profileState = .loaded(updatedProfile)
        case .error(let error):
          profileState = .failed(error.localizedDescription)
        }
        isLoadingFollowButton = false
      }
    }

    func toggleBlocking() {
      guard case .loaded(let profile) = profileState else { return }
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
          profileState = .loaded(updatedProfile)
        case .error(let error):
          profileState = .failed(error.localizedDescription)
        }
        isLoadingBlockButton = false
      }
    }

    func toggleMuting() {
      guard case .loaded(let profile) = profileState else { return }
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
          profileState = .loaded(updatedProfile)
        case .error(let error):
          profileState = .failed(error.localizedDescription)
        }
        isLoadingMuteButton = false
      }
    }

    func handlePostAppear(at index: Int, totalCount: Int) {
      guard case .loaded(_) = profileState,
        case .loaded(_) = postsState,
        index >= totalCount - 3,
        canLoadMorePosts,
        !isLoadingMorePosts
      else { return }

      isLoadingMorePosts = true

      Task {
        await loadPosts()
      }
    }

    func reorderPostsForPin(pinnedPostId: Int) {
      guard case .loaded(var currentIds) = postsState else { return }

      // If the first post is different from the one being pinned,
      // move it to its chronological position (it was previously pinned)
      if let firstId = currentIds.first, firstId != pinnedPostId {
        repositionPostChronologically(firstId, in: &currentIds)
      }

      // Move newly pinned post to top
      currentIds.removeAll { $0 == pinnedPostId }
      currentIds.insert(pinnedPostId, at: 0)

      postsState = .loaded(currentIds)
    }

    func reorderPostsForUnpin(unpinnedPostId: Int) {
      guard case .loaded(var currentIds) = postsState else { return }

      if currentIds.contains(unpinnedPostId) {
        repositionPostChronologically(unpinnedPostId, in: &currentIds)
        postsState = .loaded(currentIds)
      } else {
        postsState = .loaded(currentIds.filter { $0 != unpinnedPostId })
      }
    }

    private func repositionPostChronologically(_ postId: Int, in currentIds: inout [Int]) {
      guard let post = postManager.getPost(id: postId) else { return }

      currentIds.removeAll { $0 == postId }
      let posts = postManager.getPostsById(currentIds)
      let insertIndex =
        posts.firstIndex { !$0.isPinned && $0.post.createdAt < post.post.createdAt }
        ?? currentIds.count
      currentIds.insert(postId, at: insertIndex)
    }
  }
}
