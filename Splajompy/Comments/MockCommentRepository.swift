import Foundation

class MockCommentService: CommentServiceProtocol, @unchecked Sendable {
  private var mockComments: [Int: [DetailedComment]] = [:]
  private var mockUsers: [User] = []
  private var commentIdCounter = 1000

  init() {
    setupMockData()
  }

  func getComments(postId: Int) async -> AsyncResult<[DetailedComment]> {
    if let comments = mockComments[postId] {
      return .success(comments)
    }
    return .success([])
  }

  func toggleLike(postId: Int, commentId: Int, isLiked: Bool) async
    -> AsyncResult<EmptyResponse>
  {
    if var comments = mockComments[postId],
      let index = comments.firstIndex(where: { $0.commentId == commentId })
    {
      comments[index].isLiked = !isLiked
      mockComments[postId] = comments
      return .success(EmptyResponse())
    }
    return .error(
      NSError(
        domain: "MockError",
        code: 404,
        userInfo: [NSLocalizedDescriptionKey: "Comment not found"]
      )
    )
  }

  func addComment(postId: Int, text: String) async -> AsyncResult<DetailedComment> {
    let newCommentId = commentIdCounter
    commentIdCounter += 1

    let currentDate = ISO8601DateFormatter().string(from: Date())
    let currentUser =
      mockUsers.first
      ?? User(
        userId: 1,
        email: "test@example.com",
        username: "testuser",
        createdAt: currentDate,
        name: "Test User"
      )

    let newComment = DetailedComment(
      commentId: newCommentId,
      postId: postId,
      userId: currentUser.userId,
      text: text,
      createdAt: currentDate,
      user: currentUser,
      isLiked: false
    )

    if mockComments[postId] != nil {
      mockComments[postId]?.append(newComment)
    } else {
      mockComments[postId] = [newComment]
    }

    return .success(newComment)
  }

  private func setupMockData() {
    let currentDate = ISO8601DateFormatter().string(from: Date())

    mockUsers = [
      User(
        userId: 1,
        email: "john@example.com",
        username: "johndoe",
        createdAt: currentDate,
        name: "John Doe"
      ),
      User(
        userId: 2,
        email: "jane@example.com",
        username: "janedoe",
        createdAt: currentDate,
        name: "Jane Doe"
      ),
      User(
        userId: 3,
        email: "bob@example.com",
        username: "bobsmith",
        createdAt: currentDate,
        name: "Bob Smith"
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
          isLiked: false
        ),
        DetailedComment(
          commentId: 2,
          postId: 1,
          userId: 2,
          text: "I totally agree with this.",
          createdAt: currentDate,
          user: mockUsers[1],
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
          isLiked: false
        ),
        DetailedComment(
          commentId: 4,
          postId: 2,
          userId: 1,
          text: "Thanks for sharing this.",
          createdAt: currentDate,
          user: mockUsers[0],
          isLiked: false
        ),
      ],
    ]
  }
}

class MockCommentService_Empty: CommentServiceProtocol, @unchecked Sendable {
  func getComments(postId: Int) async -> AsyncResult<[DetailedComment]> {
    return .success([])
  }

  func toggleLike(postId: Int, commentId: Int, isLiked: Bool) async -> AsyncResult<EmptyResponse> {
    return .success(EmptyResponse())
  }

  func addComment(postId: Int, text: String) async -> AsyncResult<DetailedComment> {
    let user = User(
      userId: 1, email: "test@example.com", username: "testuser",
      createdAt: ISO8601DateFormatter().string(from: Date()), name: "Test User")

    let newComment = DetailedComment(
      commentId: Int.random(in: 100...1000),
      postId: postId,
      userId: 1,
      text: text,
      createdAt: ISO8601DateFormatter().string(from: Date()),
      user: user,
      isLiked: false
    )

    return .success(newComment)
  }
}

class MockCommentService_Loading: CommentServiceProtocol, @unchecked Sendable {
  private let delay: TimeInterval
  private let mockService = MockCommentService()

  init(delay: TimeInterval = 2.0) {
    self.delay = delay
  }

  func getComments(postId: Int) async -> AsyncResult<[DetailedComment]> {
    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000_000))
    return await mockService.getComments(postId: postId)
  }

  func toggleLike(postId: Int, commentId: Int, isLiked: Bool) async -> AsyncResult<EmptyResponse> {
    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000_000))
    return await mockService.toggleLike(postId: postId, commentId: commentId, isLiked: isLiked)
  }

  func addComment(postId: Int, text: String) async -> AsyncResult<DetailedComment> {
    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000_000))
    return await mockService.addComment(postId: postId, text: text)
  }
}

class MockCommentService_Error: CommentServiceProtocol, @unchecked Sendable {
  func getComments(postId: Int) async -> AsyncResult<[DetailedComment]> {
    return .error(
      NSError(
        domain: "MockError", code: 400,
        userInfo: [NSLocalizedDescriptionKey: "Failed to load comments"]))
  }

  func toggleLike(postId: Int, commentId: Int, isLiked: Bool) async -> AsyncResult<EmptyResponse> {
    return .error(
      NSError(
        domain: "MockError", code: 400,
        userInfo: [NSLocalizedDescriptionKey: "Failed to toggle like"]))
  }

  func addComment(postId: Int, text: String) async -> AsyncResult<DetailedComment> {
    return .error(
      NSError(
        domain: "MockError", code: 400,
        userInfo: [NSLocalizedDescriptionKey: "Failed to add comment"]))
  }
}
