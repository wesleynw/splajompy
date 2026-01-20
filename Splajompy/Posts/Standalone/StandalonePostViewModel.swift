import Foundation
import SwiftUI

enum PostState {
  case idle
  case loading
  case loaded(ObservablePost)
  case failed(Error)
}

extension StandalonePostView {
  @MainActor @Observable class ViewModel {
    var state: PostState = .idle

    private var postId: Int
    private var postManager: PostStore

    init(postId: Int, postManager: PostStore) {
      self.postId = postId
      self.postManager = postManager
    }

    func load(resetLoadingState: Bool = true) async {
      if resetLoadingState {
        state = .loading
      }

      state = await postManager.loadSingleCachedPost(postId: postId)
    }

    func toggleLike() {
      Task {
        await postManager.likePost(id: postId)
      }
    }
  }
}
