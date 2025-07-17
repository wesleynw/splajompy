import Foundation
import SwiftUI

enum ProfileState {
  case idle
  case loading
  case loaded(UserProfile, [Int])
  case failed(Error)
}

extension ProfileView {
  @MainActor class ViewModel: ObservableObject {
    private let userId: Int
    private var profileService: ProfileServiceProtocol
    private var postsOffset = 0
    private let fetchLimit = 10
    private var currentPostsTask: Task<Void, Never>? = nil
    private var currentProfileTask: Task<Void, Never>? = nil
    var postManager: PostManager

    @Published var state: ProfileState = .idle
    @Published var isLoadingFollowButton = false
    @Published var isLoadingBlockButton = false
    @Published var canLoadMorePosts: Bool = true
    @Published var isLoadingMorePosts: Bool = false
    @Published var postIds: [Int] = []

    init(
      userId: Int,
      postManager: PostManager,
      profileService: ProfileServiceProtocol = ProfileService()
    ) {
      self.userId = userId
      self.postManager = postManager
      self.profileService = profileService
    }

    var posts: [DetailedPost] {
      postManager.getPostsById(postIds)
    }

    func loadProfile() async {
      currentProfileTask?.cancel()

      currentProfileTask = Task {
        async let profileResult = profileService.getProfile(userId: userId)
        async let postsResult =
          postManager.loadFeed(
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
          postManager.cachePosts(fetchedPosts)
          postIds = fetchedPosts.map { $0.id }
          postsOffset = fetchedPosts.count
          canLoadMorePosts = fetchedPosts.count >= fetchLimit
          state = .loaded(userProfile, postIds)
        case (.success(let userProfile), .error(_)):
          postIds = []
          state = .loaded(userProfile, [])
        case (.error(let error), _):
          state = .failed(error)
        }
      }

      await currentProfileTask?.value
    }

    func loadPosts(reset: Bool = false) async {
      guard case .loaded(let profile, _) = state else { return }

      currentPostsTask?.cancel()

      currentPostsTask = Task {
        if reset {
          postsOffset = 0
        } else {
          isLoadingMorePosts = true
        }

        guard !Task.isCancelled else { return }

        let result =
          await postManager.loadFeed(
            feedType: .profile,
            userId: userId,
            offset: postsOffset,
            limit: fetchLimit
          )

        guard !Task.isCancelled else { return }

        switch result {
        case .success(let fetchedPosts):
          postManager.cachePosts(fetchedPosts)
          let newPostIds = fetchedPosts.map { $0.id }

          if reset {
            postIds = newPostIds
          } else {
            postIds.append(contentsOf: newPostIds)
          }

          state = .loaded(profile, postIds)
          canLoadMorePosts = fetchedPosts.count >= fetchLimit
          postsOffset += fetchedPosts.count
        case .error(let error):
          state = .failed(error)
        }

        isLoadingMorePosts = false
      }

      await currentPostsTask?.value
    }

    func toggleLike(on post: DetailedPost) {
      Task {
        await postManager.likePost(id: post.id)
      }
    }

    func deletePost(on post: DetailedPost) {
      guard case .loaded(let profile, _) = state else { return }
      if let index = postIds.firstIndex(of: post.id) {
        postIds.remove(at: index)
        state = .loaded(profile, postIds)
        Task {
          await postManager.deletePost(id: post.id)
        }
      }
    }

    func updateProfile(name: String, bio: String) {
      Task {
        let result = await profileService.updateProfile(name: name, bio: bio)
        switch result {
        case .success(_):
          if case .loaded(var profile, let postIds) = state {
            profile.name = name
            profile.bio = bio
            state = .loaded(profile, postIds)
          }
        case .error(_):
          break
        }
      }
    }

    func toggleFollowing() {
      guard case .loaded(let profile, let postIds) = state else { return }
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
          state = .loaded(updatedProfile, postIds)
        }
        isLoadingFollowButton = false
      }
    }

    func toggleBlocking() {
      guard case .loaded(let profile, let postIds) = state else { return }
      Task {
        isLoadingBlockButton = true
        let result = await profileService.toggleBlocking(
          userId: userId,
          isBlocking: profile.isBlocking
        )
        if case .error(let error) = result {
          print("Error toggling blocking status: \(error.localizedDescription)")
        } else {
          var updatedProfile = profile
          updatedProfile.isBlocking.toggle()
          updatedProfile.isFollower = false
          state = .loaded(updatedProfile, postIds)
        }
        isLoadingBlockButton = false
      }
    }
  }
}
