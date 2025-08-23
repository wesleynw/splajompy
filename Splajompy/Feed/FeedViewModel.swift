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

  var posts: [DetailedPost] {
    postManager.getPostsById(postIds)
  }

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
    } else {
      isLoadingMore = true
    }

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
    case .success(let fetchedPosts):
      let newPostIds = fetchedPosts.map { $0.id }

      if reset {
        postIds = newPostIds
        state = .loaded(newPostIds)
      } else {
        postIds.append(contentsOf: newPostIds)
        state = .loaded(postIds)
      }

      canLoadMore = fetchedPosts.count >= fetchLimit

      // Update cursor timestamp to the oldest post in the batch
      if let oldestPost = fetchedPosts.last {
        lastPostTimestamp = oldestPost.post.createdAt
      } else {
        // If no posts fetched, we've reached the end
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
      state = .loaded(postIds)
      Task {
        await postManager.deletePost(id: post.id)
      }
    }
  }
}
