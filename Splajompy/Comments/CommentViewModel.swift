import Foundation

extension CommentsView {
  @MainActor class ViewModel: ObservableObject {
    private let postId: Int
    private var service: CommentServiceProtocol

    @Published var comments = [DetailedComment]()
    @Published var isLoading = true

    init(postId: Int, service: CommentServiceProtocol = CommentService()) {
      self.postId = postId
      self.service = service
      loadComments()
    }

    func loadComments() {
      Task {
        isLoading = true

        let result = await service.getComments(postId: postId)

        switch result {
        case .success(let fetchedComments):
          comments = fetchedComments
        case .error(let error):
          print("Error fetching comments: \(error.localizedDescription)")
        }

        isLoading = false
      }
    }

    func toggleLike(for comment: DetailedComment) {
      Task {
        // Optimistic update TODO: this is broken
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
        // TODO: update parent viewModel with comment count
      }
    }

    func addComment(text: String) {
      Task {
        let result = await service.addComment(postId: postId, text: text)

        switch result {
        case .success(let newComment):
          comments.append(newComment)
        // TODO: update comment count in parent VM
        case .error(let error):
          print("Error adding comment: \(error.localizedDescription)")
        }
      }
    }
  }
}
