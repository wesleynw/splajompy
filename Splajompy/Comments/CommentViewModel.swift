import SwiftUI

enum CommentState {
  case idle
  case loading
  case loaded([DetailedComment])
  case failed(Error)
}

extension CommentsView {
  @MainActor class ViewModel: ObservableObject {
    private let postId: Int
    private var service: CommentServiceProtocol
    @AppStorage("comment_sort_order") private var commentSortOrder: String =
      "Newest First"

    @Published var state: CommentState = .idle
    @Published var isSubmitting: Bool = false
    @Published var showError: Bool = false
    @Published var errorMessage: String?
    @ObservedObject var postManager: PostManager

    @Published var text: NSAttributedString = NSAttributedString(string: "")
    @Published var cursorPosition: Int = 0

    init(
      postId: Int,
      service: CommentServiceProtocol = CommentService(),
      postManager: PostManager
    ) {
      self.postId = postId
      self.service = service
      self.postManager = postManager
      loadComments()
    }

    func loadComments() {
      state = .loading

      Task {
        let result = await service.getComments(postId: postId)

        switch result {
        case .success(let fetchedComments):
          state = .loaded(sortComments(fetchedComments))
          postManager.updatePost(
            id: postId,
            updates: { post in post.commentCount = fetchedComments.count }
          )
        case .error(let error):
          state = .failed(error)
        }
      }
    }

    func toggleLike(for comment: DetailedComment) {
      guard case .loaded(var currentComments) = state else { return }

      guard
        let index = currentComments.firstIndex(where: {
          $0.commentId == comment.commentId
        })
      else { return }

      currentComments[index].isLiked.toggle()
      state = .loaded(currentComments)

      Task {
        let result = await service.toggleLike(
          postId: comment.postId,
          commentId: comment.commentId,
          isLiked: comment.isLiked
        )

        if case .error(let error) = result {
          print("Error toggling like: \(error.localizedDescription)")
          guard case .loaded(var revertComments) = state else { return }
          if let index = revertComments.firstIndex(where: {
            $0.commentId == comment.commentId
          }) {
            revertComments[index].isLiked.toggle()
            state = .loaded(revertComments)
          }
        }
      }
    }

    private func parseCommentDate(_ createdAt: String) -> Date {
      let dateFormatter = ISO8601DateFormatter()
      dateFormatter.formatOptions = [
        .withInternetDateTime, .withFractionalSeconds,
      ]
      return dateFormatter.date(from: createdAt) ?? Date()
    }

    private func sortComments(_ comments: [DetailedComment])
      -> [DetailedComment]
    {
      return comments.sorted { comment1, comment2 in
        let date1 = parseCommentDate(comment1.createdAt)
        let date2 = parseCommentDate(comment2.createdAt)

        if commentSortOrder == "Oldest First" {
          return date1 < date2
        } else {
          return date1 > date2
        }
      }
    }

    private func addCommentToList(_ comment: DetailedComment) {
      guard case .loaded(var currentComments) = state else { return }

      if commentSortOrder == "Oldest First" {
        currentComments.append(comment)
      } else {
        currentComments.insert(comment, at: 0)
      }

      state = .loaded(currentComments)
    }

    func submitComment(text: String) async -> Bool {
      let text = text.trimmingCharacters(
        in: .whitespacesAndNewlines
      )
      guard !text.isEmpty else { return false }

      isSubmitting = true
      defer { isSubmitting = false }

      let result = await service.addComment(postId: postId, text: text)

      switch result {
      case .success(let newComment):
        addCommentToList(newComment)

        postManager.updatePost(id: postId) { post in
          post.commentCount += 1
        }

        return true
      case .error(let error):
        print("Error adding comment: \(error.localizedDescription)")
        errorMessage = error.localizedDescription
        showError = true
        return false
      }
    }

    func resetInputState() {
      text = NSAttributedString(string: "")
      cursorPosition = 0
    }

    func deleteComment(_ comment: DetailedComment) async {
      guard case .loaded(var currentComments) = state else { return }

      guard
        let index = currentComments.firstIndex(where: {
          $0.commentId == comment.commentId
        })
      else { return }

      currentComments.remove(at: index)
      state = .loaded(currentComments)

      let result = await service.deleteComment(commentId: comment.commentId)

      if case .error(let error) = result {
        print("Error deleting comment: \(error.localizedDescription)")
        guard case .loaded(var revertComments) = state else { return }
        revertComments.insert(comment, at: index)
        state = .loaded(revertComments)
      }
    }
  }
}
