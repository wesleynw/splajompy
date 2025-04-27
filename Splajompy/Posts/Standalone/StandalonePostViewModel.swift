import Foundation

enum PostState {
  case idle
  case loading
  case loaded(DetailedPost)
  case failed(Error)
}

extension StandalonePostView {
  @MainActor class ViewModel: ObservableObject {
    @Published var post: PostState = .idle

    private var postId: Int
    private var postService: PostServiceProtocol

    init(
      postId: Int,
      postService: PostServiceProtocol = PostService()
    ) {
      self.postId = postId
      self.postService = postService
    }

    func load() async {
      let postResult = await postService.getPostById(postId: postId)

      switch postResult {
      case .success(let fetchedPost):
        post = .loaded(fetchedPost)

      case .error(let error):
        post = .failed(error)
      }
    }

    func toggleLike() {
      Task {
        guard case .loaded(let detailedPost) = post else { return }

        var updatedPost = detailedPost
        updatedPost.isLiked.toggle()
        post = .loaded(updatedPost)

        let result = await postService.toggleLike(
          postId: detailedPost.id,
          isLiked: !updatedPost.isLiked
        )

        if case .error(let error) = result {
          print("Error toggling like: \(error.localizedDescription)")
          updatedPost.isLiked.toggle()
          post = .loaded(updatedPost)
        }
      }
    }

  }
}
