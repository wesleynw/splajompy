import Foundation

class MockCommentService: CommentServiceProtocol, @unchecked Sendable {
  private var mockComments: [Int: [DetailedComment]] = [:]
  private var mockUsers: [PublicUser] = []
  private var commentIdCounter = 1000

  init() {
    setupMockData()
  }

  func getComments(postId: Int) async -> Result<[DetailedComment], Error> {
    if let comments = mockComments[postId] {
      return .success(comments)
    }
    return .success([])
  }

  func toggleLike(postId: Int, commentId: Int, isLiked: Bool) async
    -> Result<Void, Error>
  {
    if var comments = mockComments[postId],
      let index = comments.firstIndex(where: { $0.commentId == commentId })
    {
      comments[index].isLiked = !isLiked
      mockComments[postId] = comments
      return .success(())
    }
    return .failure(
      NSError(
        domain: "MockError",
        code: 404,
        userInfo: [NSLocalizedDescriptionKey: "Comment not found"]
      )
    )
  }

  func addComment(postId: Int, text: String, image: PlatformImage?) async -> Result<
    DetailedComment, Error
  > {
    let newCommentId = commentIdCounter
    commentIdCounter += 1

    let currentDate = Date()
    let currentUser =
      mockUsers.first
      ?? PublicUser(
        userId: 1,
        username: "testuser",
        createdAt: Date(),
        name: "Test User",
        isVerified: false,
        displayProperties: UserDisplayProperties(fontChoiceId: 0)
      )

    let newComment = DetailedComment(
      commentId: newCommentId,
      postId: postId,
      userId: currentUser.userId,
      text: text,
      createdAt: currentDate,
      user: currentUser,
      facets: [],
      images: nil,
      isLiked: false
    )

    if mockComments[postId] != nil {
      mockComments[postId]?.append(newComment)
    } else {
      mockComments[postId] = [newComment]
    }

    return .success(newComment)
  }

  func deleteComment(commentId: Int) async -> Result<Void, Error> {
    for (postId, var comments) in mockComments {
      if let index = comments.firstIndex(where: { $0.commentId == commentId }) {
        comments.remove(at: index)
        mockComments[postId] = comments
        return .success(())
      }
    }
    return .failure(
      NSError(
        domain: "MockError",
        code: 404,
        userInfo: [NSLocalizedDescriptionKey: "Comment not found"]
      )
    )
  }

  private func setupMockData() {
    let currentDate = Date()

    mockUsers = [
      PublicUser(
        userId: 1,
        username: "johndoe",
        createdAt: Date(),
        name: "John Doe",
        isVerified: false,
        displayProperties: UserDisplayProperties(fontChoiceId: 0)
      ),
      PublicUser(
        userId: 2,
        username: "janedoe",
        createdAt: Date(),
        name: "Jane Doe",
        isVerified: false,
        displayProperties: UserDisplayProperties(fontChoiceId: 0)
      ),
      PublicUser(
        userId: 3,
        username: "bobsmith",
        createdAt: Date(),
        name: "Bob Smith",
        isVerified: false,
        displayProperties: UserDisplayProperties(fontChoiceId: 0)
      ),
    ]

    mockComments = [
      1: [
        DetailedComment(
          commentId: 1,
          postId: 1,
          userId: 1,
          text: "Great post!",
          createdAt: currentDate,
          user: mockUsers[0],
          facets: [],
          images: nil,
          isLiked: false
        ),
        DetailedComment(
          commentId: 2,
          postId: 1,
          userId: 2,
          text: "I totally agree with this.",
          createdAt: currentDate,
          user: mockUsers[1],
          facets: [],
          images: nil,
          isLiked: true
        ),
      ],
      2: [
        DetailedComment(
          commentId: 3,
          postId: 2,
          userId: 3,
          text: "Interesting perspective.",
          createdAt: currentDate,
          user: mockUsers[2],
          facets: [],
          images: nil,
          isLiked: false
        ),
        DetailedComment(
          commentId: 4,
          postId: 2,
          userId: 1,
          text: "Thanks for sharing this.",
          createdAt: currentDate,
          user: mockUsers[0],
          facets: [],
          images: nil,
          isLiked: false
        ),
      ],
    ]
  }
}

class MockCommentService_Empty: CommentServiceProtocol, @unchecked Sendable {
  func getComments(postId: Int) async -> Result<[DetailedComment], Error> {
    return .success([])
  }

  func toggleLike(postId: Int, commentId: Int, isLiked: Bool) async -> Result<Void, Error> {
    return .success(())
  }

  func addComment(postId: Int, text: String, image: PlatformImage?) async -> Result<
    DetailedComment, Error
  > {
    let currentDate = Date()
    let user = PublicUser(
      userId: 1,
      username: "testuser",
      createdAt: currentDate,
      name: "Test User",
      isVerified: false,
      displayProperties: UserDisplayProperties(fontChoiceId: 0)
    )

    let newComment = DetailedComment(
      commentId: Int.random(in: 100...1000),
      postId: postId,
      userId: 1,
      text: text,
      createdAt: Date(),
      user: user,
      facets: [],
      images: nil,
      isLiked: false
    )

    return .success(newComment)
  }

  func deleteComment(commentId: Int) async -> Result<Void, Error> {
    return .success(())
  }
}

class MockCommentService_Loading: CommentServiceProtocol, @unchecked Sendable {
  private let delay: TimeInterval
  private let mockService = MockCommentService()

  init(delay: TimeInterval = 2.0) {
    self.delay = delay
  }

  func getComments(postId: Int) async -> Result<[DetailedComment], Error> {
    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000_000))
    return await mockService.getComments(postId: postId)
  }

  func toggleLike(postId: Int, commentId: Int, isLiked: Bool) async -> Result<Void, Error> {
    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000_000))
    return await mockService.toggleLike(postId: postId, commentId: commentId, isLiked: isLiked)
  }

  func addComment(postId: Int, text: String, image: PlatformImage?) async -> Result<
    DetailedComment, Error
  > {
    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000_000))
    return await mockService.addComment(postId: postId, text: text, image: nil)
  }

  func deleteComment(commentId: Int) async -> Result<Void, Error> {
    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000_000))
    return await mockService.deleteComment(commentId: commentId)
  }
}

class MockCommentService_Error: CommentServiceProtocol, @unchecked Sendable {
  func getComments(postId: Int) async -> Result<[DetailedComment], Error> {
    return .failure(
      NSError(
        domain: "MockError", code: 400,
        userInfo: [NSLocalizedDescriptionKey: "Failed to load comments"]))
  }

  func toggleLike(postId: Int, commentId: Int, isLiked: Bool) async -> Result<Void, Error> {
    return .failure(
      NSError(
        domain: "MockError", code: 400,
        userInfo: [NSLocalizedDescriptionKey: "Failed to toggle like"]))
  }

  func addComment(postId: Int, text: String, image: PlatformImage?) async -> Result<
    DetailedComment, Error
  > {
    return .failure(
      NSError(
        domain: "MockError", code: 400,
        userInfo: [NSLocalizedDescriptionKey: "Failed to add comment"]))
  }

  func deleteComment(commentId: Int) async -> Result<Void, Error> {
    return .failure(
      NSError(
        domain: "MockError", code: 400,
        userInfo: [NSLocalizedDescriptionKey: "Failed to delete comment"]))
  }
}
