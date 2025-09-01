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
  case loaded([DetailedPost])
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
    @Published var isLoadingFollowButton = false
    @Published var isLoadingBlockButton = false
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
      // only load posts if we don't have any yet
      if case .loaded(let currentPosts) = postsState, !currentPosts.isEmpty {
        profileState = .loading
        let result = await profileService.getProfile(userId: userId)
        switch result {
        case .success(let userProfile):
          profileState = .loaded(userProfile)
        case .error(let error):
          profileState = .failed(error.localizedDescription)
        }
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

        // update cursor timestamp to the oldest post in the batch
        if let oldestPost = fetchedPosts.last {
          lastPostTimestamp = oldestPost.post.createdAt
        }

        canLoadMorePosts = fetchedPosts.count >= fetchLimit
        postsState = .loaded(fetchedPosts)
      case .error(let error):
        postsState = .failed(error.localizedDescription)
      }
    }

    func loadPosts(reset: Bool = false) async {
      guard case .loaded(_) = profileState else { return }

      if reset {
        lastPostTimestamp = nil
      } else {
        guard canLoadMorePosts && !isLoadingMorePosts else { return }
        guard case .loaded(_) = postsState else { return }
        isLoadingMorePosts = true
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
        let finalPosts: [DetailedPost]
        if reset {
          finalPosts = fetchedPosts
        } else {
          if case .loaded(let currentPosts) = postsState {
            finalPosts = currentPosts + fetchedPosts
          } else {
            finalPosts = fetchedPosts
          }
        }

        // update cursor timestamp to the oldest post in the batch
        if let oldestPost = fetchedPosts.last {
          lastPostTimestamp = oldestPost.post.createdAt
        }

        postsState = .loaded(finalPosts)
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
      if case .loaded(let currentPosts) = postsState,
        let index = currentPosts.firstIndex(where: { $0.id == post.id })
      {
        var updatedPosts = currentPosts
        updatedPosts.remove(at: index)
        postsState = .loaded(updatedPosts)
        Task {
          await postManager.deletePost(id: post.id)
        }
      }
    }

    func updateProfile(name: String, bio: String) {
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
  }
}
