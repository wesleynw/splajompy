import Foundation
import SwiftUI

extension CommentsView {
  @MainActor class ViewModel: ObservableObject {
    private let postId: Int
    private var service: CommentServiceProtocol
    @AppStorage("comment_sort_order") private var commentSortOrder: String = "Newest First"

    @Published var comments = [DetailedComment]()
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    @ObservedObject var postManager: PostManager

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
      Task {
        isLoading = true

        let result = await service.getComments(postId: postId)

        switch result {
        case .success(let fetchedComments):
          comments = sortComments(fetchedComments)
        case .error(let error):
          print("Error fetching comments: \(error.localizedDescription)")
        }

        isLoading = false
      }
    }

    func toggleLike(for comment: DetailedComment) {
      Task {
        if let index = comments.firstIndex(where: {
          $0.commentId == comment.commentId
        }) {
          comments[index].isLiked.toggle()

          let result = await service.toggleLike(
            postId: comment.postId,
            commentId: comment.commentId,
            isLiked: comment.isLiked
          )

          if case .error(let error) = result {
            print("Error toggling like: \(error.localizedDescription)")
            if let index = comments.firstIndex(where: {
              $0.commentId == comment.commentId
            }) {
              comments[index].isLiked.toggle()
            }
          }
        }
      }
    }

    private func parseCommentDate(_ createdAt: String) -> Date {
      let dateFormatter = ISO8601DateFormatter()
      dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
      return dateFormatter.date(from: createdAt) ?? Date()
    }

    private func sortComments(_ comments: [DetailedComment]) -> [DetailedComment] {
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
      if commentSortOrder == "Oldest First" {
        comments.append(comment)
      } else {
        comments.insert(comment, at: 0)
      }
    }

    func submitComment(text: String) async -> Bool {
      isLoading = true
      defer {
        isLoading = false
      }
      
      let text = text.trimmingCharacters(
        in: .whitespacesAndNewlines
      )
      guard !text.isEmpty else { return false }
      
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
        self.errorMessage = error.localizedDescription
        self.showError = true
        return false
      }
    }

    func deleteComment(_ comment: DetailedComment) async {
      if let index = comments.firstIndex(where: { $0.commentId == comment.commentId }) {
        comments.remove(at: index)

        let result = await service.deleteComment(commentId: comment.commentId)

        if case .error(let error) = result {
          print("Error deleting comment: \(error.localizedDescription)")
          comments.insert(comment, at: index)
          errorMessage = "Failed to delete comment"
          showError = true
        }
      }
    }
  }
}
