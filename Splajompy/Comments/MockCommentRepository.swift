import Foundation

class MockCommentService: CommentServiceProtocol, @unchecked Sendable {
  private var mockComments: [Int: [DetailedComment]] = [:]
  private var mockUsers: [PublicUser] = []
  private var commentIdCounter = 0

  func getComments(postId: Int) async -> Result<[DetailedComment], Error> {
    if let comments = mockComments[postId] {
      return .success(comments)
    }
    return .success([])
  }

  private var notFound: Result<Void, Error> {
    .failure(
      NSError(
        domain: "MockError",
        code: 404,
        userInfo: [NSLocalizedDescriptionKey: "Comment not found"]
      )
    )
  }

  func toggleLike(postId: Int, commentId: Int, isLiked: Bool) async
    -> Result<Void, Error>
  {
    guard var comments = mockComments[postId] else { return notFound }
    for i in comments.indices {
      if comments[i].commentId == commentId {
        comments[i].isLiked = !isLiked
        mockComments[postId] = comments
        return .success(())
      }
      if let j = comments[i].children?.firstIndex(where: {
        $0.commentId == commentId
      }) {
        comments[i].children?[j].isLiked = !isLiked
        mockComments[postId] = comments
        return .success(())
      }
    }
    return notFound
  }

  func addComment(
    postId: Int,
    commentId: Int?,
    text: String,
    imageData: ImageData?
  ) async
    -> Result<
      DetailedComment, Error
    >
  {
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
      isLiked: false,
      parentCommentId: commentId
    )

    if mockComments[postId] != nil {
      if let parentId = commentId {
        guard
          let parentIndex = mockComments[postId]?
            .firstIndex(where: { $0.commentId == parentId })
        else {
          return .failure(
            NSError(
              domain: "MockError",
              code: 404,
              userInfo: [NSLocalizedDescriptionKey: "Parent comment not found"]
            )
          )
        }

        var children = mockComments[postId]![parentIndex].children ?? []
        children.append(newComment)
        mockComments[postId]![parentIndex].children = children
      } else {
        mockComments[postId]?.append(newComment)
      }
    } else {
      mockComments[postId] = [newComment]
    }

    return .success(newComment)
  }

  func deleteComment(commentId: Int) async -> Result<Void, Error> {
    for (postId, var comments) in mockComments {
      if let i = comments.firstIndex(where: { $0.commentId == commentId }) {
        comments.remove(at: i)
        mockComments[postId] = comments
        return .success(())
      }
      for i in comments.indices {
        if let j = comments[i].children?.firstIndex(where: {
          $0.commentId == commentId
        }) {
          comments[i].children?.remove(at: j)
          mockComments[postId] = comments
          return .success(())
        }
      }
    }
    return notFound
  }
}

class MockCommentService_Empty: CommentServiceProtocol, @unchecked Sendable {
  func getComments(postId: Int) async -> Result<[DetailedComment], Error> {
    return .success([])
  }

  func toggleLike(postId: Int, commentId: Int, isLiked: Bool) async -> Result<
    Void, Error
  > {
    return .success(())
  }

  func addComment(
    postId: Int,
    commentId: Int?,
    text: String,
    imageData: ImageData?
  ) async
    -> Result<
      DetailedComment, Error
    >
  {
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

  func toggleLike(postId: Int, commentId: Int, isLiked: Bool) async -> Result<
    Void, Error
  > {
    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000_000))
    return await mockService.toggleLike(
      postId: postId,
      commentId: commentId,
      isLiked: isLiked
    )
  }

  func addComment(
    postId: Int,
    commentId: Int?,
    text: String,
    imageData: ImageData?
  ) async
    -> Result<
      DetailedComment, Error
    >
  {
    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000_000))
    return await mockService.addComment(
      postId: postId,
      commentId: commentId,
      text: text,
      imageData: nil
    )
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
        domain: "MockError",
        code: 400,
        userInfo: [NSLocalizedDescriptionKey: "Failed to load comments"]
      )
    )
  }

  func toggleLike(postId: Int, commentId: Int, isLiked: Bool) async -> Result<
    Void, Error
  > {
    return .failure(
      NSError(
        domain: "MockError",
        code: 400,
        userInfo: [NSLocalizedDescriptionKey: "Failed to toggle like"]
      )
    )
  }

  func addComment(
    postId: Int,
    commentId: Int?,
    text: String,
    imageData: ImageData?
  ) async
    -> Result<
      DetailedComment, Error
    >
  {
    return .failure(
      NSError(
        domain: "MockError",
        code: 400,
        userInfo: [NSLocalizedDescriptionKey: "Failed to add comment"]
      )
    )
  }

  func deleteComment(commentId: Int) async -> Result<Void, Error> {
    return .failure(
      NSError(
        domain: "MockError",
        code: 400,
        userInfo: [NSLocalizedDescriptionKey: "Failed to delete comment"]
      )
    )
  }
}
