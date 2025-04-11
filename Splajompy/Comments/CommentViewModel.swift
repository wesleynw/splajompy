import Foundation

extension CommentsView {
  @MainActor class ViewModel: ObservableObject {
    private let postId: Int

    @Published var comments = [Comment]()
    @Published var isLoading = true

    init(postId: Int) {
      self.postId = postId
      loadComments()
    }

    func loadComments() {
      Task {
        isLoading = true

        let result = await CommentService.getComments(postId: postId)

        switch result {
        case .success(let fetchedComments):
          comments = fetchedComments
        case .failure(let error):
          print("Error fetching comments: \(error.localizedDescription)")
        }

        isLoading = false
      }
    }

    func toggleLike(for comment: Comment) {
      Task {
        // Optimistic update
        if let index = comments.firstIndex(where: {
          $0.commentId == comment.commentId
        }) {
          comments[index].isLiked.toggle()

          let result = await CommentService.toggleLike(
            postId: comment.postId,
            commentId: comment.commentId,
            isLiked: comment.isLiked
          )

          if case .failure(let error) = result {
            print("Error toggling like: \(error.localizedDescription)")
            if let index = comments.firstIndex(where: {
              $0.commentId == comment.commentId
            }) {
              comments[index].isLiked.toggle()
            }
          }
        }
        // TODO: update parent viewModel with comment count
      }
    }

    func addComment(text: String) {
      Task {
        let result = await CommentService.addComment(postId: postId, text: text)

        switch result {
        case .success(let newComment):
          comments.append(newComment)
        // TODO: update comment count in parent VM
        case .failure(let error):
          print("Error adding comment: \(error.localizedDescription)")
        }
      }
    }
  }
}
