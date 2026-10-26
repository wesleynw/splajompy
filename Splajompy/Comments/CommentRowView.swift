import PostHog
import SwiftUI

struct CommentRow: View {
  let comment: DetailedComment
  let isInSheet: Bool
  let toggleLike: () -> Void
  let deleteComment: () -> Void
  var handleCommentReply: (() -> Void)? = nil

  var isReadOnly: Bool = false

  let formatter = RelativeDateTimeFormatter()

  @Environment(AuthManager.self) private var authManager
  @Environment(\.openURL) private var openURL
  @State private var showDeleteConfirmation = false
  @State private var replyGestureOffset: CGFloat = CGFloat.zero
  private let replyThreshold: CGFloat = 60

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .firstTextBaseline, spacing: 2) {
        if isInSheet {
          Button {
            openURL(
              URL(
                string:
                  "splajompy://user?id=\(comment.user.userId)&username=\(comment.user.username)"
              )!
            )
          } label: {
            ProfileDisplayNameView(user: comment.user, alignVertically: false)
          }
          .buttonStyle(.plain)
        } else {
          NavigationLink(
            value: Route.profile(
              id: String(comment.user.userId),
              username: comment.user.username
            )
          ) {
            ProfileDisplayNameView(user: comment.user, alignVertically: false)
          }
          .buttonStyle(.plain)
        }
      }

      if let images = comment.images {
        ImageGallery(images: images)
          .frame(maxWidth: .infinity, maxHeight: 300, alignment: .leading)
      }

      Text(comment.richContent)
        .tint(.accentColor)

      HStack {
        TimelineView(.periodic(from: .now, by: 5)) { _ in
          Text(
            comment.createdAt
              .formatted(.relative(presentation: .named))
          )
          .font(.caption)
          .foregroundStyle(.gray)
        }

        Spacer()

        HStack {
          if let currentUser = authManager.currentUser {
            if currentUser.userId == comment.user.userId {
              Menu(
                content: {
                  Button(
                    role: .destructive,
                    action: { showDeleteConfirmation = true }
                  ) {
                    Label("Delete", systemImage: "trash")
                      .foregroundStyle(.red)
                  }
                },
                label: {
                  Image(systemName: "ellipsis")
                    .font(.system(size: 16))
                    .frame(width: 32, height: 32)
                    .contentShape(.rect)
                }
              )
              .buttonStyle(.plain)
            }
          }

          if let commentReplyCallback = handleCommentReply,
            PostHogSDK.shared.isFeatureEnabled("comment-replies")
          {
            Button {
              commentReplyCallback()
            } label: {
              Image(systemName: "arrowshape.turn.up.left")
                .font(.body)
            }
            .buttonStyle(.plain)
          }

          LikeButton(isLiked: comment.isLiked, action: toggleLike)
            .allowsHitTesting(true)
        }
        .opacity(isReadOnly ? 0 : 1)
        .allowsHitTesting(!isReadOnly)
      }
      .allowsHitTesting(true)
    }
    .offset(x: replyGestureOffset)
    .animation(.default, value: replyGestureOffset)
    .contentShape(.rect)
    .gesture(
      CommentReplyGesture(
        onTrigger: handleCommentReply ?? {},
        replyGestureOffset: $replyGestureOffset
      ),
      isEnabled: PostHogSDK.shared.isFeatureEnabled("comment-replies")
        && comment.parentCommentId == nil && handleCommentReply != nil
    )
    .sensoryFeedback(.impact, trigger: replyGestureOffset > replyThreshold)
    .background(alignment: .leading) {
      Image(systemName: "arrowshape.turn.up.left")
        .font(.body)
        .scaleEffect(replyGestureOffset > replyThreshold ? 1.2 : 1)
        .opacity(replyIndicatorOpacity)
        .animation(.default, value: replyGestureOffset)
    }
    .padding(.vertical, 8)
    #if os(iOS)
      .padding(.horizontal, 16)
    #else
      .padding(.horizontal, 24)
    #endif
    .contentShape(Rectangle())
    .overlay(
      Rectangle()
        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        .mask(
          VStack(spacing: 0) {
            Spacer()
            Rectangle().frame(height: 1)
          }
        )
    )
    .alert(
      "Are you sure you want to delete this comment?",
      isPresented: $showDeleteConfirmation,
    ) {
      Button("Delete", role: .destructive) {
        deleteComment()
      }
      Button("Cancel", role: .cancel) {}
    }

  }

  private var replyIndicatorOpacity: Double {
    let revealStart: CGFloat = 16
    let revealEnd: CGFloat = replyThreshold
    return Double(
      min(
        1,
        max(0, (replyGestureOffset - revealStart) / (revealEnd - revealStart))
      )
    )
  }
}

struct LikeButton: View {
  let isLiked: Bool
  let action: () -> Void

  var body: some View {
    Button(action: {
      action()
    }) {
      Image(systemName: isLiked ? "heart.fill" : "heart")
        .font(.system(size: 16))
        .foregroundStyle(isLiked ? Color.red.gradient : Color.primary.gradient)
        .frame(width: 32, height: 32)
        .contentShape(.rect)
        .scaleEffect(isLiked ? 1.1 : 1)
        .animation(
          .spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0),
          value: isLiked
        )
    }
    .buttonStyle(.plain)
    .sensoryFeedback(.impact, trigger: isLiked)
  }
}

#Preview {
  NavigationStack {
    CommentRow(
      comment: Mocks.comment1,
      isInSheet: false,
      toggleLike: {},
      deleteComment: {},
    )
    .environment(AuthManager())
  }
}
