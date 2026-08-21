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
  var showOlderPosts: Bool = false
  private(set) var caughtUpCutoffDate: Date = FeedViewModel.makeCutoffDate()
  private var isLoadingMore: Bool = false

  private var lastPostTimestamp: Date?
  private let fetchLimit = 10
  private var postManager: PostStore

  init(feedType: FeedType, userId: Int? = nil, postManager: PostStore) {
    self.feedType = feedType
    self.userId = userId
    self.postManager = postManager
  }

  func loadPosts(preserveCurrentState: Bool = false, reset: Bool = false) async {
    guard !isLoadingMore else { return }
    isLoadingMore = true
    defer {
      isLoadingMore = false
    }

    if reset {
      lastPostTimestamp = nil
      caughtUpCutoffDate = Self.makeCutoffDate()
      showOlderPosts = false
    }
    if !preserveCurrentState {
      state = .loading
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
      let allPosts = existingPosts + newPosts
      lastPostTimestamp = newPosts.last?.post.createdAt ?? lastPostTimestamp
      canLoadMore = newPosts.count >= fetchLimit
      state = .loaded(allPosts)
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
      await loadPosts(preserveCurrentState: true)
    }
  }

  func revealOlderPosts() {
    showOlderPosts = true
  }

  func markCaughtUp() {
    guard case .loaded(let posts) = state, let newestPostDate = posts.first?.post.createdAt
    else { return }
    UserDefaults.standard.set(newestPostDate, forKey: Self.lastCaughtUpTimestampKey)
  }

  private static let lastCaughtUpTimestampKey = "caughtUpLastSeenPostTimestamp"

  private static func makeCutoffDate() -> Date {
    let twoDaysAgo =
      Calendar.current.date(byAdding: .day, value: -2, to: Date())
      ?? Date().addingTimeInterval(-2 * 24 * 3600)
    let lastSeen = UserDefaults.standard.object(forKey: lastCaughtUpTimestampKey) as? Date
    return max(twoDaysAgo, lastSeen ?? .distantPast)
  }
}
