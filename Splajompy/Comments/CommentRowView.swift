import SwiftUI

struct CommentRow: View {
  let comment: DetailedComment
  let isInSheet: Bool
  let toggleLike: () -> Void
  let deleteComment: () -> Void

  let formatter = RelativeDateTimeFormatter()

  @Environment(AuthManager.self) private var authManager
  @Environment(\.openURL) private var openURL
  @State private var showDeleteConfirmation = false

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

        HStack(spacing: 0) {
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

          LikeButton(isLiked: comment.isLiked, action: toggleLike)
            .allowsHitTesting(true)
        }
      }
      .allowsHitTesting(true)
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
        .padding(6)
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
