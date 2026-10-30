import SwiftUI

struct CommentView: View {
  let comment: DetailedComment
  var replyToComment: Int? = nil

  let onToggleLike: (DetailedComment) -> Void
  let onDelete: (DetailedComment) -> Void
  let onCommentReply: () -> Void
  var enableReplySwipeGesture: Bool = false

  var isReadOnly: Bool = false
  var isBlurring: Bool = false
  var showChildren: Bool = true

  var replyNamespace: Namespace.ID?

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
        },
        enableReplySwipeGesure: enableReplySwipeGesture,
        isReadOnly: isReadOnly,
      )
      .modify {
        if let namespace = replyNamespace {
          $0.matchedGeometryEffect(
            id: comment.commentId,
            in: namespace,
            properties: .position
          )
        }
      }
      .blur(
        radius: replyToComment != nil
          && replyToComment
            != comment.commentId
          ? 6 : 0
      )

      if showChildren {
        childCommentsView
          .blur(radius: replyToComment != nil ? 6 : 0)
      }
    }
  }

  @ContentBuilder
  private var childCommentsView: some View {
    if let children = comment.children, children.count > 0 {
      HStack {
        Capsule()
          .foregroundStyle(.tertiary)
          .frame(width: 6)
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
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
            .animation(.default, value: child.commentId)
          }
        }
      }
      .fixedSize(horizontal: false, vertical: true)
    }
  }
}
