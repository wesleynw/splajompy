import SwiftUI

struct CommentView: View {
  let comment: DetailedComment
  var replyToComment: Int? = nil

  let onToggleLike: (DetailedComment) -> Void
  let onDelete: (DetailedComment) -> Void
  let onCommentReply: (DetailedComment) -> Void
  var enableReplySwipeGesture: Bool = false

  var isReadOnly: Bool = false
  var isBlurring: Bool = false
  var showChildren: Bool = true

  var replyNamespace: Namespace.ID?

  var body: some View {
    VStack {
      CommentRow(
        comment: comment,
        toggleLike: {
          onToggleLike(comment)
        },
        deleteComment: {
          onDelete(comment)
        },
        handleCommentReply: {
          onCommentReply(comment)
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

      if showChildren {
        childCommentsView
          .blur(radius: replyToComment != nil ? 6 : 0)
      }
    }
  }

  @ContentBuilder
  private var childCommentsView: some View {
    if let children = comment.children, !children.isEmpty {
      VStack {
        ForEach(children) { child in
          CommentRow(
            comment: child,
            toggleLike: { onToggleLike(child) },
            deleteComment: { onDelete(child) },
            handleCommentReply: {
              onCommentReply(child)
            }
          )
          .id(child.commentId)
          .transition(.opacity.combined(with: .scale(scale: 0.95)))
          .animation(.default, value: child.commentId)
        }
      }
      .padding(.leading, 28)
      .overlay(alignment: .leading) {
        Capsule()
          .foregroundStyle(.tertiary)
          .frame(width: 6)
          .padding(.vertical, 3)
          .padding(.leading)
      }
    }
  }
}
