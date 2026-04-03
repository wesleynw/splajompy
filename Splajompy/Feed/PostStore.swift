import SwiftUI

// TODO: I think it would make sense to have a utility funtion for optimistic updates, takes in an update, reversion, and server action?
// TODO: this is also just super broken. i don't even think i'm checking access order, or reusing cached entries in many cases...
// TODO: i hate this

@MainActor @Observable class ObservablePost {
  var post: Post
  var user: PublicUser
  var isLiked: Bool
  var commentCount: Int
  var images: [ImageDTO]?
  var relevantLikes: [RelevantLike]
  var hasOtherLikes: Bool
  var poll: Poll?
  var isPinned: Bool

  var id: Int { post.postId }

  init(from post: DetailedPost) {
    self.post = post.post
    self.user = post.user
    self.isLiked = post.isLiked
    self.commentCount = post.commentCount
    self.images = post.images
    self.relevantLikes = post.relevantLikes
    self.hasOtherLikes = post.hasOtherLikes
    self.poll = post.poll
    self.isPinned = post.isPinned
  }

  func update(from post: DetailedPost) {
    self.post = post.post
    self.user = post.user
    self.isLiked = post.isLiked
    self.commentCount = post.commentCount
    self.images = post.images
    self.relevantLikes = post.relevantLikes
    self.hasOtherLikes = post.hasOtherLikes
    self.poll = post.poll
    self.isPinned = post.isPinned
  }
}

@MainActor @Observable
class PostStore {
  private let postService: PostServiceProtocol

  private(set) var posts: [Int: ObservablePost] = [:]
  private(set) var isLoadingPost: [Int: Bool] = [:]

  private var cacheAccessOrder: [Int] = []

  init(postService: PostServiceProtocol = PostService()) {
    self.postService = postService
  }

  func getPost(id: Int) -> ObservablePost? {
    updateAccessOrder(for: id)
    return posts[id]
  }

  func getPostsById(_ ids: [Int]) -> [ObservablePost] {
    return ids.compactMap { posts[$0] }
  }

  func isLoading(postId: Int) -> Bool {
    return isLoadingPost[postId] ?? false
  }

  func setLoading(postId: Int, loading: Bool) {
    isLoadingPost[postId] = loading
  }

  func cachePost(_ apiPost: DetailedPost) {
    if let existing = posts[apiPost.id] {
      existing.update(from: apiPost)
    } else {
      posts[apiPost.id] = ObservablePost(from: apiPost)
    }
    updateAccessOrder(for: apiPost.id)
  }

  func cachePosts(_ apiPosts: [DetailedPost]) {
    for post in apiPosts {
      cachePost(post)
    }
  }

  func updatePost(id: Int, updates: (ObservablePost) -> Void) {
    guard let post = posts[id] else { return }
    updates(post)
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

  func loadSingleCachedPost(postId: Int) async -> PostState {
    if let cachedPost = getPost(id: postId) {
      return .loaded(cachedPost)
    }

    let result = await postService.getPostById(postId: postId)

    switch result {
    case .success(let post):
      cachePost(post)
      if let post = getPost(id: postId) {
        return .loaded(post)
      } else {
        return .idle
      }
    case .error(let error):
      return .failed(error)
    }
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
      isLiked: !currentPost.isLiked
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

  func voteInPoll(postId: Int, optionIndex: Int) async {
    guard let post = getPost(id: postId), post.poll?.currentUserVote == nil
    else { return }

    // optimistic update
    if let poll = post.poll, poll.options.count > optionIndex {
      updatePost(id: postId) { post in
        post.poll?.voteTotal += 1
        post.poll?.options[optionIndex].voteTotal += 1
        post.poll?.currentUserVote = optionIndex
      }

      let result = await postService.voteOnPostPoll(
        postId: postId,
        optionIndex: optionIndex
      )

      if case .error = result {
        print("error voting on post: \(postId)")

        // revert update on failure
        updatePost(id: postId) { post in
          post.poll?.voteTotal -= 1
          post.poll?.options[optionIndex].voteTotal -= 1
          post.poll?.currentUserVote = nil
        }
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

  func loadSinglePost(postId: Int) async -> AsyncResult<DetailedPost> {
    let result = await postService.getPostById(postId: postId)

    return result
  }

  func loadFeed(
    feedType: FeedType,
    userId: Int? = nil,
    beforeTimestamp: Date?,
    limit: Int
  )
    async
    -> AsyncResult<[DetailedPost]>
  {
    let result = await postService.getPostsForFeedCursor(
      feedType: feedType,
      userId: userId,
      beforeTimestamp: beforeTimestamp,
      limit: limit
    )

    if case .success(let posts) = result {
      cachePosts(posts)
    }

    return result
  }

  func pinPost(id: Int) async -> Bool {
    guard posts[id] != nil else { return false }

    let previouslyPinnedPostId = currentUserPinnedPostId()

    if let previousId = previouslyPinnedPostId {
      updatePost(id: previousId) { $0.isPinned = false }
    }

    updatePost(id: id) { $0.isPinned = true }

    let result = await postService.pinPost(postId: id)

    if case .error(let error) = result {
      print(
        "PostManager: Failed to pin post \(id): \(error.localizedDescription)"
      )
      updatePost(id: id) { $0.isPinned = false }
      if let previousId = previouslyPinnedPostId {
        updatePost(id: previousId) { $0.isPinned = true }
      }
      return false
    }

    return true
  }

  func unpinPost() async -> Bool {
    guard let postId = currentUserPinnedPostId() else { return false }

    updatePost(id: postId) { $0.isPinned = false }

    let result = await postService.unpinPost()

    if case .error(let error) = result {
      print("PostManager: Failed to unpin post: \(error.localizedDescription)")
      updatePost(id: postId) { $0.isPinned = true }
      return false
    }

    return true
  }

  private func currentUserPinnedPostId() -> Int? {
    guard let currentUserId = AuthManager.shared.getCurrentUser()?.userId else {
      return nil
    }
    return posts.first {
      $0.value.user.userId == currentUserId && $0.value.isPinned
    }?.key
  }

  private func updateAccessOrder(for id: Int) {
    if let index = cacheAccessOrder.firstIndex(of: id) {
      cacheAccessOrder.remove(at: index)
    }
    cacheAccessOrder.append(id)
  }
}
