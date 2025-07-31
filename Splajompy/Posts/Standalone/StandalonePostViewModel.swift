import Foundation
import SwiftUI

enum PostState {
  case idle
  case loading
  case loaded(Int)
  case failed(Error)
}

extension StandalonePostView {
  @MainActor class ViewModel: ObservableObject {
    @Published var post: PostState = .idle

    var detailedPost: DetailedPost? {
      postManager.getPost(id: postId)
    }

    private var postId: Int
    @ObservedObject private var postManager: PostManager

    init(postId: Int, postManager: PostManager) {
      self.postId = postId
      self.postManager = postManager
    }

    func load() async {
      // Check if post is already cached
      if postManager.getPost(id: postId) != nil {
        post = .loaded(postId)
        return
      }

      post = .loading
      await postManager.loadPost(id: postId)

      if postManager.getPost(id: postId) != nil {
        post = .loaded(postId)
      } else {
        post = .failed(NSError(domain: "PostNotFound", code: 404))
      }
    }

    func toggleLike() {
      Task {
        await postManager.likePost(id: postId)
      }
    }
  }
}
