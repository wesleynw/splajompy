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
      postService: PostServiceProtocol = PostService(),
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

  }
}
