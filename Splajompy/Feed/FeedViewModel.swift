import PostHog
import SwiftUI

enum FeedState {
  case idle
  case loading
  case loaded([ObservablePost])
  case failed(Error)
}

@MainActor @Observable class FeedViewModel {
  var feedType: FeedType
  var userId: Int?
  var canLoadMore: Bool = true
  var state: FeedState = .idle
  private var isLoadingMore: Bool = false

  private var lastPostTimestamp: Date?
  private let fetchLimit = 10
  private var postManager: PostStore

  init(feedType: FeedType, userId: Int? = nil, postManager: PostStore) {
    self.feedType = feedType
    self.userId = userId
    self.postManager = postManager
  }

  func refreshPosts() async {
    state = .loading
    lastPostTimestamp = nil

    await loadPosts(reset: true)
  }

  func loadPosts(reset: Bool = false) async {
    guard !isLoadingMore else { return }
    isLoadingMore = true
    defer {
      isLoadingMore = false
    }

    let result = await postManager.loadFeed(
      feedType: feedType,
      userId: userId,
      beforeTimestamp: lastPostTimestamp,
      limit: fetchLimit
    )

    switch result {
    case .success(let newPosts):
      let existingPosts: [ObservablePost]
      if case .loaded(let posts) = state, !reset {
        existingPosts = posts
      } else {
        existingPosts = []
      }
      lastPostTimestamp = newPosts.last?.post.createdAt ?? lastPostTimestamp
      canLoadMore = newPosts.count >= fetchLimit
      state = .loaded(existingPosts + newPosts)
    case .failure(let error):
      state = .failed(error)
    }
  }

  func toggleLike(on post: ObservablePost) async {
    await postManager.togglePostLiked(id: post.id)
  }

  func incrementCommentCount(on post: ObservablePost) async {
    postManager.incrementCommentCount(for: post.id)
  }

  func deletePost(on post: ObservablePost) {
    guard case .loaded(let posts) = state else { return }
    state = .loaded(posts.filter { $0.id != post.id })
    PostHogSDK.shared.capture("post_deleted")
    Task {
      await postManager.deletePost(id: post.id)
    }
  }

  func handlePostAppear(at index: Int) {
    guard case .loaded(let currentPostIds) = state,
      index >= currentPostIds.count - 3,
      canLoadMore,
      !isLoadingMore
    else { return }

    Task {
      await loadPosts()
    }
  }
}
