import Foundation
import SwiftUI

enum PostState {
  case idle
  case loading
  case loaded(Int)
  case failed(Error)
}

extension StandalonePostView {
  @MainActor @Observable class ViewModel {
    var post: PostState = .idle

    var detailedPost: ObservablePost? {
      postManager.getPost(id: postId)
    }

    private var postId: Int
    private var postManager: PostStore

    init(postId: Int, postManager: PostStore) {
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
