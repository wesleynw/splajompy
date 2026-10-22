import SwiftUI

struct ScrollToCommentWhenAddedModifier: ViewModifier {
  let commentId: Int
  let viewModel: CommentsView.ViewModel
  let proxy: ScrollViewProxy?

  func body(content: Content) -> some View {
    content
      .onAppear {
        guard viewModel.pendingScrollCommentId == commentId else { return }
        viewModel.pendingScrollCommentId = nil
        withAnimation {
          proxy?.scrollTo(
            commentId,
            anchor: viewModel.commentSortOrder == "Oldest First" ? .bottom : .top
          )
        }
      }
  }
}

extension View {
  func scrollToCommentWhenAdded(
    _ commentId: Int,
    viewModel: CommentsView.ViewModel,
    proxy: ScrollViewProxy?
  ) -> some View {
    modifier(
      ScrollToCommentWhenAddedModifier(commentId: commentId, viewModel: viewModel, proxy: proxy))
  }
}
