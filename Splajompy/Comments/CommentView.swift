import SwiftUI

struct CommentView: View {
  let comment: DetailedComment

  let onToggleLike: (DetailedComment) -> Void
  let onDelete: (DetailedComment) -> Void
  let onAppear: (DetailedComment) -> Void
  let onCommentReply: () -> Void

  var body: some View {
    VStack {
      CommentRow(
        comment: comment,
        isInSheet: true,
        toggleLike: {
          onToggleLike(comment)
        },
        deleteComment: {
          onDelete(comment)
        },
        handleCommentReply: {
          onCommentReply()
        }
      )
      .id(comment.commentId)
      .geometryGroup()
      .transition(.opacity.combined(with: .scale(scale: 0.95)))
      .onAppear {
        onAppear(comment)
      }

      childCommentsView
    }
  }

  @ContentBuilder
  private var childCommentsView: some View {
    if let children = comment.children, children.count > 0 {
      HStack {
        Capsule()
          .foregroundStyle(.tertiary)
          .frame(width: 4)
          .frame(maxHeight: .infinity)
          .padding(.vertical, 3)
          .padding(.leading)

        VStack {
          ForEach(children) { child in
            CommentRow(
              comment: child,
              isInSheet: false,
              toggleLike: {
                onToggleLike(child)
              },
              deleteComment: {
                onDelete(child)
              }
            )
            .id(child.commentId)
            .geometryGroup()
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
            .onAppear {
              onAppear(child)
            }
          }
        }
      }
      .fixedSize(horizontal: false, vertical: true)
    }
  }
}
