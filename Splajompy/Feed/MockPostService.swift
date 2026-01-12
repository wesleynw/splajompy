import Foundation

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
      4135: DetailedPost(
        post: Post(
          postId: 4135,
          userId: 151,
          text:
            "I foresee the stained glass community on Splajompy growing rapidly in 2026",
          createdAt: baseDate.addingTimeInterval(-200),
          facets: nil
        ),
        user: PublicUser(
          userId: 151,
          username: "milesperhour",
          createdAt: formatter.string(
            from: baseDate.addingTimeInterval(-15_206_400)
          ),
          name: "Miles The Splajoracle",
          isVerified: false,
          displayProperties: UserDisplayProperties(fontChoiceId: 2)
        ),
        isLiked: true,
        commentCount: 1,
        images: [],
        relevantLikes: [
          RelevantLike(username: "sydknee", userId: 231),
          RelevantLike(username: "freakoftheweek", userId: 43),
        ],
        hasOtherLikes: true,
        isPinned: false
      ),

      4423: DetailedPost(
        post: Post(
          postId: 4423,
          userId: 179,
          text:
            "i may not be an efficient stardew valley player, but no one's farm looks better than mine and that's a fact",
          createdAt: baseDate.addingTimeInterval(-321),
          facets: nil
        ),
        user: PublicUser(
          userId: 179,
          username: "camtalpa",
          createdAt: formatter.string(
            from: baseDate.addingTimeInterval(-13_392_000)
          ),
          name: "camalicious",
          isVerified: false,
          displayProperties: UserDisplayProperties(fontChoiceId: 7)
        ),
        isLiked: true,
        commentCount: 4,
        images: [],
        relevantLikes: [
          RelevantLike(username: "bessbb", userId: 139),
          RelevantLike(username: "freakoftheweek", userId: 43),
        ],
        hasOtherLikes: true,
        isPinned: false
      ),

      4107: DetailedPost(
        post: Post(
          postId: 4107,
          userId: 231,
          text: "Chickpeas.",
          createdAt: baseDate.addingTimeInterval(-430),
          facets: nil
        ),
        user: PublicUser(
          userId: 231,
          username: "sydknee",
          createdAt: formatter.string(
            from: baseDate.addingTimeInterval(-10_368_000)
          ),
          name: "🪲🐌🐞 Sydney 🐞🐌🪲",
          isVerified: false,
          displayProperties: UserDisplayProperties(fontChoiceId: 8)
        ),
        isLiked: true,
        commentCount: 6,
        images: [],
        relevantLikes: [
          RelevantLike(username: "freakoftheweek", userId: 43)
        ],
        hasOtherLikes: true,
        poll: Poll(
          title: "Chickpeas",
          voteTotal: 24,
          currentUserVote: 0,
          options: [
            PollOption(title: "Hot", voteTotal: 21),
            PollOption(title: "Not", voteTotal: 3),
          ]
        ),
        isPinned: false
      ),

      2001: DetailedPost(
        post: Post(
          postId: 2001,
          userId: 6,
          text:
            "just discovered this amazing coffee shop ☕ perfect latte art and the vibes are immaculate",
          createdAt: baseDate.addingTimeInterval(-7200),
          facets: nil
        ),
        user: PublicUser(
          userId: 6,
          username: "wesley",
          createdAt: formatter.string(
            from: baseDate.addingTimeInterval(-25_920_000)
          ),
          name: "Wesley",
          isVerified: false,
          displayProperties: UserDisplayProperties(fontChoiceId: 0)
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
        user: PublicUser(
          userId: 6,
          username: "wesley",
          createdAt: formatter.string(
            from: baseDate.addingTimeInterval(-25_920_000)
          ),
          name: "Wesley",
          isVerified: false,
          displayProperties: UserDisplayProperties(fontChoiceId: 0)
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
        user: PublicUser(
          userId: 1,
          username: "wesleynw",
          createdAt: formatter.string(
            from: baseDate.addingTimeInterval(-31_536_000)
          ),
          name: "Wesley 🌌",
          isVerified: true,
          displayProperties: UserDisplayProperties(fontChoiceId: 0)
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
        user: PublicUser(
          userId: 15,
          username: "marketvendor",
          createdAt: formatter.string(
            from: baseDate.addingTimeInterval(-2_592_000)
          ),
          name: "Market Maven",
          isVerified: false,
          displayProperties: UserDisplayProperties(fontChoiceId: 0)
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
        user: PublicUser(
          userId: 30,
          username: "giuseppe",
          createdAt: formatter.string(
            from: baseDate.addingTimeInterval(-5_184_000)
          ),
          name: "DROP TABLE users; --",
          isVerified: false,
          displayProperties: UserDisplayProperties(fontChoiceId: 0)
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
        user: PublicUser(
          userId: 120,
          username: "realsophie",
          createdAt: formatter.string(
            from: baseDate.addingTimeInterval(-18_144_000)
          ),
          name: "Sophie",
          isVerified: false,
          displayProperties: UserDisplayProperties(fontChoiceId: 0)
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
        user: PublicUser(
          userId: 25,
          username: "joel",
          createdAt: formatter.string(
            from: baseDate.addingTimeInterval(-20_736_000)
          ),
          name: "Joel",
          isVerified: false,
          displayProperties: UserDisplayProperties(fontChoiceId: 0)
        ),
        isLiked: false,
        commentCount: 1,
        images: nil,
        relevantLikes: [],
        hasOtherLikes: true,
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
