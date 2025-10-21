import Foundation

enum FeedType: String, CaseIterable {
  case home
  case all
  case profile
  case mutual
  case following
}

protocol PostServiceProtocol: Sendable {
  func getPostById(postId: Int) async -> AsyncResult<DetailedPost>
  func getPostsForFeedCursor(
    feedType: FeedType,
    userId: Int?,
    beforeTimestamp: Date?,
    limit: Int
  ) async -> AsyncResult<[DetailedPost]>
  func toggleLike(postId: Int, isLiked: Bool) async -> AsyncResult<
    EmptyResponse
  >
  func addComment(postId: Int, content: String) async -> AsyncResult<
    EmptyResponse
  >
  func deletePost(postId: Int) async -> AsyncResult<EmptyResponse>
  func reportPost(postId: Int) async -> AsyncResult<EmptyResponse>
  func voteOnPostPoll(postId: Int, optionIndex: Int) async -> AsyncResult<
    EmptyResponse
  >
  func pinPost(postId: Int) async -> AsyncResult<EmptyResponse>
  func unpinPost() async -> AsyncResult<EmptyResponse>
}

struct PostService: PostServiceProtocol {
  private let fetchLimit = 10

  func getPostById(postId: Int) async -> AsyncResult<DetailedPost> {
    return await APIService.performRequest(endpoint: "post/\(postId)")
  }

  func getPostsForFeedCursor(
    feedType: FeedType,
    userId: Int? = nil,
    beforeTimestamp: Date?,
    limit: Int
  ) async -> AsyncResult<[DetailedPost]> {
    let urlBase: String
    switch feedType {
    case .home:
      urlBase = "v2/posts/following"
    case .all:
      urlBase = "v2/posts/all"
    case .profile:
      guard let userId = userId else {
        return .error(URLError(.badURL))
      }
      urlBase = "v2/user/\(userId)/posts"
    case .mutual:
      urlBase = "v2/posts/mutual"
    case .following:
      urlBase = "v2/posts/following"
    }

    var queryItems = [
      URLQueryItem(name: "limit", value: "\(limit)")
    ]

    if let beforeTimestamp = beforeTimestamp {
      let formatter = ISO8601DateFormatter()
      formatter.formatOptions = [.withInternetDateTime, .withTimeZone]
      queryItems.append(
        URLQueryItem(name: "before", value: formatter.string(from: beforeTimestamp)))
    }

    let result: AsyncResult<[DetailedPost]> = await APIService.performRequest(
      endpoint: urlBase,
      queryItems: queryItems
    )

    return result
  }

  func toggleLike(postId: Int, isLiked: Bool) async -> AsyncResult<
    EmptyResponse
  > {
    let method = isLiked ? "DELETE" : "POST"
    return await APIService.performRequest(
      endpoint: "post/\(postId)/liked",
      method: method
    )
  }

  func addComment(postId: Int, content: String) async -> AsyncResult<
    EmptyResponse
  > {
    let bodyData: [String: String] = ["Text": content]
    let jsonData: Data
    do {
      jsonData = try JSONEncoder().encode(bodyData)
    } catch {
      return .error(error)
    }
    return await APIService.performRequest(
      endpoint: "post/\(postId)/comment",
      method: "POST",
      body: jsonData
    )
  }

  func deletePost(postId: Int) async -> AsyncResult<EmptyResponse> {
    return await APIService.performRequest(
      endpoint: "post/\(postId)",
      method: "DELETE"
    )
  }

  func reportPost(postId: Int) async -> AsyncResult<EmptyResponse> {
    return await APIService.performRequest(
      endpoint: "post/\(postId)/report",
      method: "POST"
    )
  }

  func voteOnPostPoll(postId: Int, optionIndex: Int) async -> AsyncResult<
    EmptyResponse
  > {
    return await APIService.performRequest(
      endpoint: "post/\(postId)/vote/\(optionIndex)",
      method: "POST"
    )
  }

  func pinPost(postId: Int) async -> AsyncResult<EmptyResponse> {
    return await APIService.performRequest(
      endpoint: "posts/\(postId)/pin",
      method: "POST"
    )
  }

  func unpinPost() async -> AsyncResult<EmptyResponse> {
    return await APIService.performRequest(
      endpoint: "posts/pin",
      method: "DELETE"
    )
  }
}

final class MockPostStore: @unchecked Sendable {
  static let shared = MockPostStore()

  private let formatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  var posts: [Int: DetailedPost]
  var deletedPostIds: Set<Int> = []
  var pinnedPostId: Int? = 2001

  init() {
    let baseDate = Date()
    let imageUrl =
      "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/posts/6/1055/2c741d27-325a-46dd-a721-d5a7594ba66a.jpeg"
    let coffeeImageUrl =
      "https://www.acouplecooks.com/wp-content/uploads/2021/05/Latte-Art-070.jpg"

    self.posts = [
      2001: DetailedPost(
        post: Post(
          postId: 2001,
          userId: 6,
          text:
            "just discovered this amazing coffee shop ☕ perfect latte art and the vibes are immaculate",
          createdAt: baseDate.addingTimeInterval(-7200),
          facets: nil
        ),
        user: User(
          userId: 6,
          email: "wesley@example.com",
          username: "wesley",
          createdAt: baseDate.addingTimeInterval(-25_920_000),
          name: "Wesley",
          isVerified: false
        ),
        isLiked: true,
        commentCount: 3,
        images: [
          ImageDTO(
            imageId: 1001,
            postId: 2001,
            height: 1000,
            width: 800,
            imageBlobUrl: coffeeImageUrl,
            displayOrder: 0
          )
        ],
        relevantLikes: [
          RelevantLike(username: "joel", userId: 25),
          RelevantLike(username: "giuseppe", userId: 112),
        ],
        hasOtherLikes: false,
        isPinned: true
      ),

      2002: DetailedPost(
        post: Post(
          postId: 2002,
          userId: 6,
          text:
            "beautiful sunset from my balcony tonight 🌅 the colors are absolutely stunning",
          createdAt: baseDate.addingTimeInterval(-14400),
          facets: nil
        ),
        user: User(
          userId: 6,
          email: "wesley@example.com",
          username: "wesley",
          createdAt: baseDate.addingTimeInterval(-25_920_000),
          name: "Wesley",
          isVerified: false
        ),
        isLiked: false,
        commentCount: 1,
        images: nil,
        relevantLikes: [],
        hasOtherLikes: false,
        isPinned: false
      ),

      2003: DetailedPost(
        post: Post(
          postId: 2003,
          userId: 1,
          text: "@sophie you up rn? need to show you something wild",
          createdAt: baseDate.addingTimeInterval(-10800),
          facets: [
            Facet(type: "mention", userId: 6, indexStart: 0, indexEnd: 7)
          ]
        ),
        user: User(
          userId: 1,
          email: "wesleynw@pm.me",
          username: "wesleynw",
          createdAt: baseDate.addingTimeInterval(-31_536_000),
          name: "Wesley 🌌",
          isVerified: true
        ),
        isLiked: false,
        commentCount: 0,
        images: nil,
        relevantLikes: [],
        hasOtherLikes: false,
        isPinned: false
      ),

      2004: DetailedPost(
        post: Post(
          postId: 2004,
          userId: 15,
          text:
            "weekend farmers market haul 🥕🥬🍅 supporting local vendors and eating fresh!",
          createdAt: baseDate.addingTimeInterval(-18000),
          facets: nil
        ),
        user: User(
          userId: 15,
          email: "marketvendor@example.com",
          username: "marketvendor",
          createdAt: baseDate.addingTimeInterval(-2_592_000),
          name: "Market Maven",
          isVerified: false
        ),
        isLiked: true,
        commentCount: 2,
        images: [
          ImageDTO(
            imageId: 1002,
            postId: 2004,
            height: 600,
            width: 800,
            imageBlobUrl: imageUrl,
            displayOrder: 0
          )
        ],
        relevantLikes: [
          RelevantLike(username: "splazackly", userId: 103)
        ],
        hasOtherLikes: true,
        isPinned: false
      ),

      2005: DetailedPost(
        post: Post(
          postId: 2005,
          userId: 30,
          text:
            "thoughts on the new season finale? 📺 that plot twist was absolutely wild!",
          createdAt: baseDate.addingTimeInterval(-28800),
          facets: nil
        ),
        user: User(
          userId: 30,
          email: "showrunner@example.com",
          username: "giuseppe",
          createdAt: baseDate.addingTimeInterval(-5_184_000),
          name: "DROP TABLE users; --",
          isVerified: false
        ),
        isLiked: false,
        commentCount: 5,
        images: nil,
        relevantLikes: [
          RelevantLike(username: "elena", userId: 97)
        ],
        hasOtherLikes: true,
        isPinned: false
      ),

      2006: DetailedPost(
        post: Post(
          postId: 2006,
          userId: 120,
          text:
            "morning walks hit different when the weather is perfect like this ☀️",
          createdAt: baseDate.addingTimeInterval(-3600),
          facets: nil
        ),
        user: User(
          userId: 120,
          email: "sophie@example.com",
          username: "realsophie",
          createdAt: baseDate.addingTimeInterval(-18_144_000),
          name: "Sophie",
          isVerified: false
        ),
        isLiked: true,
        commentCount: 0,
        images: nil,
        relevantLikes: [],
        hasOtherLikes: false,
        isPinned: false
      ),

      2007: DetailedPost(
        post: Post(
          postId: 2007,
          userId: 25,
          text:
            "spreading good vibes today 💕 hope everyone is having an amazing day!",
          createdAt: baseDate.addingTimeInterval(-5400),
          facets: nil
        ),
        user: User(
          userId: 25,
          email: "joel@example.com",
          username: "joel",
          createdAt: baseDate.addingTimeInterval(-20_736_000),
          name: "Joel",
          isVerified: false
        ),
        isLiked: false,
        commentCount: 1,
        images: nil,
        relevantLikes: [],
        hasOtherLikes: true,
        isPinned: false
      ),

      2008: DetailedPost(
        post: Post(
          postId: 2008,
          userId: 1,
          text:
            "building splajompy has been such an incredible journey 🚀 excited to share what's coming next",
          createdAt: baseDate.addingTimeInterval(0),
          facets: nil
        ),
        user: User(
          userId: 1,
          email: "wesleynw@pm.me",
          username: "wesleynw",
          createdAt: baseDate.addingTimeInterval(-31_536_000),
          name: "Wesley 🔥",
          isVerified: true
        ),
        isLiked: true,
        commentCount: 4,
        images: nil,
        relevantLikes: [
          RelevantLike(username: "wesley", userId: 6),
          RelevantLike(username: "giuseppe", userId: 113),
        ],
        hasOtherLikes: true,
        isPinned: false
      ),
      1998: DetailedPost(
        post: Post(
          postId: 1998,
          userId: 30,
          text: "What's your favorite way to start the morning? ☀️",
          createdAt: baseDate.addingTimeInterval(-1),
          facets: nil
        ),
        user: User(
          userId: 30,
          email: "showrunner@example.com",
          username: "giuseppe",
          createdAt: baseDate.addingTimeInterval(-5_184_000),
          name: "DROP TABLE users; --",
          isVerified: false
        ),
        isLiked: false,
        commentCount: 2,
        images: nil,
        relevantLikes: [
          RelevantLike(username: "wesley", userId: 6)
        ],
        hasOtherLikes: true,
        poll: Poll(
          title: "Morning routine poll",
          voteTotal: 12,
          currentUserVote: 1,
          options: [
            PollOption(title: "Coffee first ☕", voteTotal: 7),
            PollOption(title: "Exercise 💪", voteTotal: 3),
            PollOption(title: "Check phone 📱", voteTotal: 2),
          ]
        ),
        isPinned: false
      ),

      2000: DetailedPost(
        post: Post(
          postId: 2000,
          userId: 1,
          text:
            "check this out: Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.",
          createdAt: baseDate.addingTimeInterval(-10_800_000),
          facets: nil
        ),
        user: User(
          userId: 1,
          email: "wesleynw@pm.me",
          username: "wesleynw",
          createdAt: baseDate.addingTimeInterval(-31_536_000),
          name: "Wesley 🌌",
          isVerified: true
        ),
        isLiked: false,
        commentCount: 0,
        images: nil,
        relevantLikes: [],
        hasOtherLikes: false,
        isPinned: false
      ),

      1999: DetailedPost(
        post: Post(
          postId: 1999,
          userId: 1,
          text: "i just found this amazing coffee shop",
          createdAt: baseDate.addingTimeInterval(-11_800_000),
          facets: nil
        ),
        user: User(
          userId: 1,
          email: "wesleynw@pm.me",
          username: "wesleynw",
          createdAt: baseDate.addingTimeInterval(-31_536_000),
          name: "Wesley 🌌",
          isVerified: true
        ),
        isLiked: false,
        commentCount: 0,
        images: nil,
        relevantLikes: [],
        hasOtherLikes: false,
        isPinned: false
      ),

    ]
  }

  func getPostsByUserId(_ userId: Int) -> [DetailedPost] {
    return posts.values.filter {
      $0.user.userId == userId && !deletedPostIds.contains($0.post.postId)
    }
    .sorted { $0.post.createdAt > $1.post.createdAt }
  }

  func getAllPosts() -> [DetailedPost] {
    return posts.values.filter { !deletedPostIds.contains($0.post.postId) }
      .sorted { $0.post.createdAt > $1.post.createdAt }
  }
}

struct MockPostService: PostServiceProtocol {
  private let store = MockPostStore.shared

  func getPostById(postId: Int) async -> AsyncResult<DetailedPost> {
    try? await Task.sleep(nanoseconds: 300_000_000)

    if store.deletedPostIds.contains(postId) {
      return .error(APIErrorMessage(message: "Post not found"))
    }

    if let post = store.posts[postId] {
      return .success(post)
    } else {
      return .error(APIErrorMessage(message: "Post not found"))
    }
  }

  func getPostsForFeedCursor(
    feedType: FeedType,
    userId: Int? = nil,
    beforeTimestamp: Date?,
    limit: Int
  ) async -> AsyncResult<[DetailedPost]> {
    try? await Task.sleep(nanoseconds: 500_000_000)

    let allPosts: [DetailedPost]

    switch feedType {
    case .home:
      allPosts = store.getAllPosts()
    case .all:
      allPosts = store.getAllPosts()
    case .profile:
      guard let userId = userId else {
        return .error(
          APIErrorMessage(message: "User ID required for profile feed")
        )
      }
      allPosts = store.getPostsByUserId(userId)
    case .mutual:
      allPosts = store.getAllPosts()
    case .following:
      allPosts = store.getAllPosts()
    }

    // Sort posts by createdAt DESC to match database behavior
    let sortedPosts = allPosts.sorted { $0.post.createdAt > $1.post.createdAt }

    // Filter by timestamp if provided
    let filteredPosts: [DetailedPost]
    if let beforeTimestamp = beforeTimestamp {
      filteredPosts = sortedPosts.filter { $0.post.createdAt < beforeTimestamp }
    } else {
      filteredPosts = sortedPosts
    }

    let paginatedPosts = Array(filteredPosts.prefix(limit))
    return .success(paginatedPosts)
  }

  func toggleLike(postId: Int, isLiked: Bool) async -> AsyncResult<
    EmptyResponse
  > {
    try? await Task.sleep(nanoseconds: 200_000_000)

    if store.deletedPostIds.contains(postId) {
      return .error(APIErrorMessage(message: "Post not found"))
    }

    if var post = store.posts[postId] {
      post.isLiked = !isLiked
      store.posts[postId] = post
      return .success(EmptyResponse())
    } else {
      return .error(APIErrorMessage(message: "Post not found"))
    }
  }

  func addComment(postId: Int, content: String) async -> AsyncResult<
    EmptyResponse
  > {
    try? await Task.sleep(nanoseconds: 400_000_000)

    if store.deletedPostIds.contains(postId) {
      return .error(APIErrorMessage(message: "Post not found"))
    }

    if var post = store.posts[postId] {
      post.commentCount += 1
      store.posts[postId] = post
      return .success(EmptyResponse())
    } else {
      return .error(APIErrorMessage(message: "Post not found"))
    }
  }

  func deletePost(postId: Int) async -> AsyncResult<EmptyResponse> {
    try? await Task.sleep(nanoseconds: 300_000_000)

    if store.posts[postId] != nil {
      store.deletedPostIds.insert(postId)
      return .success(EmptyResponse())
    } else {
      return .error(APIErrorMessage(message: "Post not found"))
    }
  }

  func reportPost(postId: Int) async -> AsyncResult<EmptyResponse> {
    try? await Task.sleep(nanoseconds: 300_000_000)

    if store.posts[postId] != nil {
      return .success(EmptyResponse())
    } else {
      return .error(APIErrorMessage(message: "Post not found"))
    }
  }

  func voteOnPostPoll(postId: Int, optionIndex: Int) async -> AsyncResult<
    EmptyResponse
  > {
    // TODO: implementation
    return .success(EmptyResponse())
  }

  func pinPost(postId: Int) async -> AsyncResult<EmptyResponse> {
    try? await Task.sleep(nanoseconds: 300_000_000)

    if store.deletedPostIds.contains(postId) {
      return .error(APIErrorMessage(message: "Post not found"))
    }

    if var post = store.posts[postId] {
      // Update previous pinned post if any
      if let previousPinnedId = store.pinnedPostId,
        var previousPost = store.posts[previousPinnedId]
      {
        previousPost.isPinned = false
        store.posts[previousPinnedId] = previousPost
      }

      // Pin new post
      post.isPinned = true
      store.posts[postId] = post
      store.pinnedPostId = postId

      return .success(EmptyResponse())
    } else {
      return .error(APIErrorMessage(message: "Post not found"))
    }
  }

  func unpinPost() async -> AsyncResult<EmptyResponse> {
    try? await Task.sleep(nanoseconds: 300_000_000)

    if let pinnedId = store.pinnedPostId,
      var post = store.posts[pinnedId]
    {
      post.isPinned = false
      store.posts[pinnedId] = post
      store.pinnedPostId = nil
      return .success(EmptyResponse())
    }

    return .success(EmptyResponse())
  }
}
