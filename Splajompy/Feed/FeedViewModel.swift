import Foundation
import SwiftUI

enum FeedState {
  case idle
  case loading
  case loaded([Int])
  case failed(Error)
}

@MainActor class FeedViewModel: ObservableObject {
  var feedType: FeedType
  var userId: Int?
  @Published var canLoadMore: Bool = true
  @Published var state: FeedState = .idle
  @Published var isLoadingMore: Bool = false
  @Published var postIds: [Int] = []
  @Published var posts: [DetailedPost] = []

  private var lastPostTimestamp: Date?
  private let fetchLimit = 10
  @ObservedObject var postManager: PostManager

  init(feedType: FeedType, userId: Int? = nil, postManager: PostManager) {
    self.feedType = feedType
    self.userId = userId
    self.postManager = postManager
  }

  func loadPosts(reset: Bool = false, useLoadingState: Bool = false) async {
    if reset {
      if useLoadingState == true {
        state = .loading
      } else if case .idle = state {
        state = .loading
      }
      lastPostTimestamp = nil
    }

    defer {
      if !reset {
        isLoadingMore = false
      }
    }

    let result = await postManager.loadFeed(
      feedType: feedType,
      userId: userId,
      beforeTimestamp: lastPostTimestamp,
      limit: fetchLimit
    )

    switch result {
    case .success(let fetchedPosts):
      let newPostIds = fetchedPosts.map { $0.id }
      let hasMorePosts = fetchedPosts.count >= fetchLimit
      let lastTimestamp = fetchedPosts.last?.post.createdAt

      if reset {
        postIds = newPostIds
        posts = fetchedPosts
      } else {
        postIds.append(contentsOf: newPostIds)
        posts.append(contentsOf: fetchedPosts)
      }
      state = .loaded(postIds)
      canLoadMore = hasMorePosts
      lastPostTimestamp = lastTimestamp ?? lastPostTimestamp

      if lastTimestamp == nil {
        canLoadMore = false
      }

    case .error(let error):
      state = .failed(error)
    }
  }

  func toggleLike(on post: DetailedPost) {
    Task {
      await postManager.likePost(id: post.id)
    }
  }

  func addComment(on post: DetailedPost, content: String) {
    Task {
      postManager.incrementCommentCount(for: post.id)
    }
  }

  func deletePost(on post: DetailedPost) {
    if let index = postIds.firstIndex(of: post.id) {
      postIds.remove(at: index)
      posts.remove(at: index)
      state = .loaded(postIds)
      Task {
        await postManager.deletePost(id: post.id)
      }
    }
  }

  func handlePostAppear(for post: DetailedPost) {
    guard case .loaded = state,
      canLoadMore,
      !isLoadingMore,
      posts.count >= 3
    else { return }

    // Check if this post is one of the last 3
    let lastThreePosts = posts.suffix(3)
    guard lastThreePosts.contains(where: { $0.id == post.id }) else { return }

    isLoadingMore = true

    Task {
      await loadPosts()
    }
  }
}
