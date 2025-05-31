import Foundation

enum FeedState {
  case idle
  case loading
  case loaded([DetailedPost])
  case failed(Error)
}

@MainActor class FeedViewModel: ObservableObject {
  var feedType: FeedType
  var userId: Int?
  
  @Published var canLoadMore: Bool = true
  @Published var state: FeedState = .idle
  @Published var posts = [DetailedPost]()
  @Published var hasMorePosts = true

  private var offset = 0
  private let fetchLimit = 10
  private var service: PostServiceProtocol

  init(
    feedType: FeedType,
    userId: Int? = nil,
    service: PostServiceProtocol = PostService()
  ) {
    self.feedType = feedType
    self.userId = userId
    self.service = service
  }

  func loadPosts(reset: Bool = false) async {
    if reset {
      if case .idle = state {
        state = .loading
      }
      offset = 0
    }

    let result = await service.getPostsForFeed(
      feedType: feedType,
      userId: userId,
      offset: offset,
      limit: fetchLimit
    )

    switch result {
    case .success(let fetchedPosts):
      if case .loaded(let existingPosts) = state, !reset {
        state = .loaded(existingPosts + fetchedPosts)
      } else {
        state = .loaded(fetchedPosts)
      }
      canLoadMore = fetchedPosts.count >= fetchLimit
      offset += fetchedPosts.count
    case .error(let error):
      state = .failed(error)
    }
  }

  func toggleLike(on post: DetailedPost) {
    guard case .loaded(var posts) = state else { return }

    if let index = posts.firstIndex(where: {
      $0.post.postId == post.post.postId
    }) {
      posts[index].isLiked.toggle()
      state = .loaded(posts)

      Task {
        let result = await service.toggleLike(
          postId: post.post.postId,
          isLiked: post.isLiked
        )

        if case .error(let error) = result {
          print("Error toggling like: \(error.localizedDescription)")
          guard case .loaded(var currentPosts) = state,
            let revertIndex = currentPosts.firstIndex(where: {
              $0.post.postId == post.post.postId
            })
          else { return }
          currentPosts[revertIndex].isLiked.toggle()
          state = .loaded(currentPosts)
        }
      }
    }
  }

  func addComment(on post: DetailedPost, content: String) {
    guard case .loaded(var posts) = state else { return }

    if let index = posts.firstIndex(where: {
      $0.post.postId == post.post.postId
    }) {
      posts[index].commentCount += 1
      state = .loaded(posts)

      Task {
        let result = await service.addComment(
          postId: post.post.postId,
          content: content
        )

        if case .error(let error) = result {
          print("Error adding comment: \(error.localizedDescription)")
          guard case .loaded(var currentPosts) = state,
            let revertIndex = currentPosts.firstIndex(where: {
              $0.post.postId == post.post.postId
            })
          else { return }
          currentPosts[revertIndex].commentCount -= 1
          state = .loaded(currentPosts)
        }
      }
    }
  }

  func deletePost(on post: DetailedPost) {
    guard case .loaded(var posts) = state else { return }

    if let index = posts.firstIndex(where: {
      $0.post.postId == post.post.postId
    }) {
      posts.remove(at: index)
      state = .loaded(posts)

      Task {
        await service.deletePost(postId: post.post.postId)
      }
    }
  }
}
