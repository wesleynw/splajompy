import Foundation

extension FeedView {
  @MainActor class ViewModel: ObservableObject {
    var feedType: FeedType
    var userId: Int?

    @Published var posts = [DetailedPost]()
    @Published var isLoading = true
    @Published var hasMorePosts = true
    @Published var error = ""

    private var isLoadingMore = false
    private var offset = 0
    private let fetchLimit = 10
    private var service: PostServiceProtocol
    
    // dependency injection so we can eventually provide a mock service here for posts and previews
    init(feedType: FeedType, userId: Int? = nil, service: PostServiceProtocol = PostService()) {
      self.feedType = feedType
      self.userId = userId
      self.service = service
      Task { @MainActor in
        loadMorePosts()
      }
    }

    func loadMorePosts(reset: Bool = false) {
      guard !isLoadingMore else { return }
      guard reset || hasMorePosts else { return }

      isLoadingMore = true
      isLoading = true

      if reset {
        offset = 0
      }

      Task {
        let result = await service.getPostsForFeed(
          feedType: feedType,
          userId: userId,
          offset: offset,
          limit: fetchLimit
        )

        switch result {
        case .success(let fetchedPosts):
          if reset {
            self.posts = fetchedPosts
          } else {
            self.posts.append(contentsOf: fetchedPosts)
          }

          hasMorePosts = fetchedPosts.count >= fetchLimit
          offset += fetchLimit
          error = ""
        case .error(let fetchError):
          error = fetchError.localizedDescription
        }

        isLoading = false
        isLoadingMore = false
      }
    }

    func refreshPosts() {
      Task {
        offset = 0
        loadMorePosts(reset: true)
      }
    }

    func toggleLike(on post: DetailedPost) {
      Task {
        if let index = posts.firstIndex(where: {
          $0.post.postId == post.post.postId
        }) {
          // Optimistic update
          posts[index].isLiked.toggle()

          let result = await service.toggleLike(
            postId: post.post.postId,
            isLiked: post.isLiked
          )

          if case .error(let error) = result {
            print("Error toggling like: \(error.localizedDescription)")
            if let index = posts.firstIndex(where: {
              $0.post.postId == post.post.postId
            }) {
              posts[index].isLiked.toggle()
            }
          }
        }
      }
    }

    func addComment(on post: DetailedPost, content: String) {
      Task {
        if let index = posts.firstIndex(where: {
          $0.post.postId == post.post.postId
        }) {
          // Optimistic update
          posts[index].commentCount += 1

          let result = await service.addComment(
            postId: post.post.postId,
            content: content
          )

          if case .error(let error) = result {
            print("Error adding comment: \(error.localizedDescription)")
            if let index = posts.firstIndex(where: {
              $0.post.postId == post.post.postId
            }) {
              posts[index].commentCount -= 1
            }
          }
        }
      }
    }
  }
}
