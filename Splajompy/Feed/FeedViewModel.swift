import PostHog
import SwiftUI

enum FeedState {
  case idle
  case loading
  case caughtUp
  case loaded([ObservablePost])
  case failed(Error)
}

let caughtUpCursorKey: String = "caught_up_cursor"

@MainActor @Observable class FeedViewModel {
  var feedType: FeedType
  var userId: Int?
  var canLoadMore: Bool = true
  var state: FeedState = .idle
  var refreshTrigger: Bool = false
  private var isLoadingMore: Bool = false

  private var cursor: Date?
  private let fetchLimit = 10
  private var postManager: PostStore

  private var sessionStartTimestamp: Date = Date()
  private var sessionEndTimestamp: Date = Date()
  private(set) var isShowingCaughtUpFooter: Bool = false
  private(set) var isCaughtUpFooterDismissed: Bool = false

  init(feedType: FeedType, userId: Int? = nil, postManager: PostStore) {
    self.feedType = feedType
    self.userId = userId
    self.postManager = postManager
  }

  var isLoading: Bool {
    if case .loading = state {
      return true
    }

    return false
  }

  func loadPosts(preserveCurrentState: Bool = false, reset: Bool = false) async {
    guard !isLoadingMore else { return }
    isLoadingMore = true
    defer {
      isLoadingMore = false
    }

    if reset {
      cursor = nil
      isCaughtUpFooterDismissed = false
      sessionEndTimestamp = Date()
      refreshTrigger.toggle()
    }
    if !preserveCurrentState {
      state = .loading
    }

    let result = await postManager.loadFeed(
      feedType: feedType,
      userId: userId,
      beforeTimestamp: cursor,
      limit: fetchLimit
    )

    switch result {
    case .success(var newPosts):
      // are we all caught up?
      let isCaughtUpFeatureEnabled: Bool = UserDefaults.standard.bool(
        forKey: "caught_up_enabled"
      )

      let caughtUpCursor = SessionHistoryService.getCatchUpThreshold()
      if let caughtUpCursor,
        let mostRecentPostTimestamp = newPosts.first?.post.createdAt,
        caughtUpCursor > mostRecentPostTimestamp,
        !isCaughtUpFooterDismissed,
        isCaughtUpFeatureEnabled
      {
        state = .caughtUp
        return
      }

      // will we catch up?
      if let caughtUpCursor,
        newPosts.contains(where: { $0.post.createdAt < caughtUpCursor }),
        !isCaughtUpFooterDismissed, isCaughtUpFeatureEnabled
      {
        newPosts = newPosts.filter({ $0.post.createdAt > caughtUpCursor })
        isShowingCaughtUpFooter = true
      }

      cursor = newPosts.last?.post.createdAt ?? cursor
      canLoadMore = newPosts.count >= fetchLimit  // this is dumb, need a flag from API

      // append to feed
      if case .loaded(let currentPosts) = state, !reset {
        state = .loaded(currentPosts + newPosts)
      } else {
        state = .loaded(newPosts)
      }
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
    withAnimation {
      state = .loaded(posts.filter { $0.id != post.id })
    }
    PostHogSDK.shared.capture("post_deleted")
    Task {
      await postManager.deletePost(id: post.id)
    }
  }

  func setHasReachedCaughtUp() {
    if let caughtUp = SessionHistoryService.getCatchUpThreshold() {
      sessionStartTimestamp = min(sessionEndTimestamp, caughtUp)
      persistSession()
    }
  }

  func setContinuePastCaughtUp() async {
    if case .caughtUp = state {
      state = .loading
    }

    canLoadMore = true

    isCaughtUpFooterDismissed = true
    await loadPosts(preserveCurrentState: true)
  }

  func handlePostAppear(for post: ObservablePost, at index: Int) {
    markPostAsSeen(for: post)
    loadMorePostsIfNeeded(at: index)
  }

  private func markPostAsSeen(for post: ObservablePost) {
    print("marking post as seen @ \(post.post.createdAt)")
    sessionStartTimestamp = min(sessionStartTimestamp, post.post.createdAt)
  }

  private func loadMorePostsIfNeeded(at index: Int) {
    guard case .loaded(let currentPostIds) = state,
      index >= currentPostIds.count - 3,
      canLoadMore,
      !isLoadingMore
    else { return }

    Task {
      await loadPosts(preserveCurrentState: true)
    }
  }

  func persistSession() {
    SessionHistoryService.saveSessionHistory(
      sessionStart: sessionStartTimestamp,
      sessionEnd: sessionEndTimestamp
    )
  }
}
