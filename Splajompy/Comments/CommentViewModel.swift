import Foundation

extension CommentsView {
  @MainActor class ViewModel: ObservableObject {
    private let postId: Int
    private var service: CommentServiceProtocol

    @Published var comments = [DetailedComment]()
    @Published var isLoading = true

    init(
      postId: Int,
      service: CommentServiceProtocol = CommentService()
    ) {
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

    private func addCommentToList(_ comment: DetailedComment) {
      comments.insert(comment, at: 0)
    }

    func submitComment(text: String) async {
      let result = await service.addComment(postId: postId, text: text)

      switch result {
      case .success(let newComment):
        addCommentToList(newComment)
      case .error(let error):
        print("Error adding comment: \(error.localizedDescription)")
      }
    }
  }
}
