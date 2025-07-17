import SwiftUI

@MainActor
class PostManager: ObservableObject {
  private let postService: PostServiceProtocol

  // MARK: - State Management Properties
  @Published private(set) var posts: [Int: DetailedPost] = [:]
  @Published private(set) var isLoadingPost: [Int: Bool] = [:]

  private let maxCacheSize = 200
  private var cacheAccessOrder: [Int] = []

  init(postService: PostServiceProtocol = PostService()) {
    self.postService = postService
  }

  // MARK: - State Management Methods

  func getPost(id: Int) -> DetailedPost? {
    updateAccessOrder(for: id)
    return posts[id]
  }

  func getPostsById(_ ids: [Int]) -> [DetailedPost] {
    return ids.compactMap { getPost(id: $0) }
  }

  func isLoading(postId: Int) -> Bool {
    return isLoadingPost[postId] ?? false
  }

  func setLoading(postId: Int, loading: Bool) {
    isLoadingPost[postId] = loading
  }

  func cachePost(_ post: DetailedPost) {
    posts[post.id] = post
    updateAccessOrder(for: post.id)
    enforceMaxCacheSize()
  }

  func cachePosts(_ newPosts: [DetailedPost]) {
    for post in newPosts {
      posts[post.id] = post
      updateAccessOrder(for: post.id)
    }
    enforceMaxCacheSize()
  }

  func updatePost(id: Int, updates: @escaping (inout DetailedPost) -> Void) {
    guard var post = posts[id] else { return }
    updates(&post)
    posts[id] = post
    updateAccessOrder(for: id)
  }

  func removePost(id: Int) {
    posts.removeValue(forKey: id)
    isLoadingPost.removeValue(forKey: id)
    cacheAccessOrder.removeAll { $0 == id }
  }

  func clearCache() {
    posts.removeAll()
    isLoadingPost.removeAll()
    cacheAccessOrder.removeAll()
  }

  // MARK: - Business Operations

  func loadPost(id: Int) async {
    let isLoading = self.isLoading(postId: id)
    guard !isLoading else { return }

    setLoading(postId: id, loading: true)

    let result = await postService.getPostById(postId: id)

    switch result {
    case .success(let post):
      cachePost(post)
    case .error:
      break
    }

    setLoading(postId: id, loading: false)
  }

  func likePost(id: Int) async {
    guard let currentPost = getPost(id: id) else {
      print("PostManager: Attempted to like non-existent post \(id)")
      return
    }

    // Optimistic update
    updatePost(id: id) { post in
      post.isLiked.toggle()
    }

    // Sync with server
    let result = await postService.toggleLike(
      postId: id,
      isLiked: currentPost.isLiked
    )

    if case .error(let error) = result {
      print(
        "PostManager: Failed to sync like for post \(id): \(error.localizedDescription)"
      )
      // Revert on error
      updatePost(id: id) { post in
        post.isLiked.toggle()
      }
    }
  }

  func incrementCommentCount(for postId: Int) {
    guard getPost(id: postId) != nil else {
      print(
        "PostManager: Attempted to increment comment count for non-existent post \(postId)"
      )
      return
    }
    updatePost(id: postId) { post in
      post.commentCount += 1
    }
  }

  func deletePost(id: Int) async {
    let result = await postService.deletePost(postId: id)

    switch result {
    case .success:
      removePost(id: id)
    case .error(let error):
      print(
        "PostManager: Failed to delete post \(id): \(error.localizedDescription)"
      )
    }
  }

  func loadFeed(feedType: FeedType, userId: Int? = nil, offset: Int, limit: Int)
    async
    -> AsyncResult<[DetailedPost]>
  {
    let result = await postService.getPostsForFeed(
      feedType: feedType,
      userId: userId,
      offset: offset,
      limit: limit
    )

    if case .success(let posts) = result {
      cachePosts(posts)
    }

    return result
  }

  // MARK: - Private Helper Methods

  private func updateAccessOrder(for id: Int) {
    cacheAccessOrder.removeAll { $0 == id }
    cacheAccessOrder.append(id)
  }

  private func enforceMaxCacheSize() {
    while posts.count > maxCacheSize && !cacheAccessOrder.isEmpty {
      let oldestId = cacheAccessOrder.removeFirst()
      posts.removeValue(forKey: oldestId)
      isLoadingPost.removeValue(forKey: oldestId)
    }
  }
}
