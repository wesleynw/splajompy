import Foundation
import Testing

@testable import Splajompy

struct CommentViewModelTests {
  @Test @MainActor func togglePostLike_ChildComment() async throws {
    let service = MockCommentService()

    let viewModel = CommentsContainerView.ViewModel(
      postId: 0,
      service: service,
      postManager: PostStore(postService: MockPostService())
    )

    await viewModel.loadComments()

    viewModel.text = NSAttributedString(string: "comment0")
    #expect(await viewModel.submitComment() == true)

    guard case .loaded(let afterParent) = viewModel.state else {
      Issue.record("Expected .loaded, got \( viewModel.state)")
      return
    }
    let parent = try #require(afterParent.first)
    #expect(parent.text == "comment0")

    viewModel.stageCommentReply(to: parent)
    viewModel.text = NSAttributedString(string: "comment1")
    #expect(await viewModel.submitComment() == true)

    guard case .loaded(let afterChild) = viewModel.state else {
      Issue.record("Expected .loaded, got \( viewModel.state)")
      return
    }
    let loadedParent = try #require(afterChild.first)
    let child = try #require(loadedParent.children?.first)

    await viewModel.toggleLike(for: loadedParent)
    await viewModel.toggleLike(for: child)

    guard case .loaded(let comments) = viewModel.state else {
      Issue.record("Expected .loaded, got \( viewModel.state)")
      return
    }

    #expect(comments.count == 1)
    var updatedParent = try #require(comments.first)
    #expect(updatedParent.isLiked == true)
    #expect(updatedParent.children?.count == 1)
    #expect(updatedParent.children?.first?.isLiked == true)

    await viewModel.toggleLike(for: loadedParent)
    await viewModel.toggleLike(for: child)

    guard case .loaded(let comments) = viewModel.state else {
      Issue.record("Expected .loaded, got \( viewModel.state)")
      return
    }

    #expect(comments.count == 1)
    updatedParent = try #require(comments.first)
    #expect(updatedParent.isLiked == false)
    #expect(updatedParent.children?.count == 1)
    #expect(updatedParent.children?.first?.isLiked == false)
  }

  @Test @MainActor func loadComments_UpdatesPostStoreCommentCount() async throws
  {
    let service = MockCommentService()
    let postService = MockPostService()
    let postStore = PostStore(postService: postService)

    var targetPost = await postStore.loadSingleCachedPost(postId: 0)
    guard case .loaded(let observablePost) = targetPost else {
      Issue.record("Expected .loaded, got \(targetPost)")
      return
    }
    #expect(observablePost.commentCount == 0)

    let viewModel = CommentsContainerView.ViewModel(
      postId: 0,
      service: service,
      postManager: postStore
    )

    viewModel.text = NSAttributedString(string: "comment0")
    _ = await viewModel.submitComment()

    await viewModel.loadComments()
    guard case .loaded(let currentComments) = viewModel.state else {
      Issue.record("Expected .loaded, got \( viewModel.state)")
      return
    }

    let comment0 = currentComments[0]

    viewModel.stageCommentReply(to: comment0)
    viewModel.text = NSAttributedString(string: "comment1")
    _ = await viewModel.submitComment()

    await viewModel.loadComments()

    targetPost = await postStore.loadSingleCachedPost(postId: 0)
    guard case .loaded(let observablePost) = targetPost else {
      Issue.record("Expected .loaded, got \(targetPost)")
      return
    }
    #expect(observablePost.commentCount == 2)
    
    guard case .loaded(let currentComments) = viewModel.state else {
      Issue.record("Expected .loaded, got \( viewModel.state)")
      return
    }
    
    let childComment = currentComments[0].children![0]
    await viewModel.deleteComment(childComment)
    
    guard case .loaded(let currentComments) = viewModel.state else {
      Issue.record("Expected .loaded, got \( viewModel.state)")
      return
    }
    
    #expect(currentComments.count == 1)
    targetPost = await postStore.loadSingleCachedPost(postId: 0)
    guard case .loaded(let observablePost) = targetPost else {
      Issue.record("Expected .loaded, got \(targetPost)")
      return
    }
    #expect(observablePost.commentCount == 1)
  }
}
