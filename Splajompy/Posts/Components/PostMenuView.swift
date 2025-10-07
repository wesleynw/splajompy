import Foundation
import PostHog
import SwiftUI

struct PostMenuView: View {
  let post: DetailedPost
  let showAuthor: Bool
  let isStandalone: Bool
  let onLikeButtonTapped: () -> Void
  let onPostDeleted: () -> Void
  let onPostPinned: () -> Void
  let onPostUnpinned: () -> Void

  @EnvironmentObject private var authManager: AuthManager
  @Binding var isShowingComments: Bool
  @Binding var isReporting: Bool
  @Binding var showReportAlert: Bool

  var body: some View {
    HStack(spacing: 0) {
      Menu(
        content: {
          if let currentUser = authManager.getCurrentUser() {
            if currentUser.userId == post.user.userId {
              if !showAuthor {
                if post.isPinned {
                  Button(action: onPostUnpinned) {
                    Label("Unpin", systemImage: "pin.slash")
                  }
                } else {
                  Button(action: onPostPinned) {
                    Label("Pin", systemImage: "pin")
                  }
                }
              }

              Button(role: .destructive, action: onPostDeleted) {
                Label("Delete", systemImage: "trash")
                  .foregroundColor(.red)
              }
            } else {
              Button(
                role: .destructive,
                action: {
                  Task {
                    isReporting = true
                    let _ = await PostService().reportPost(
                      postId: post.post.postId
                    )
                    isReporting = false
                    showReportAlert = true
                  }
                }
              ) {
                if isReporting {
                  HStack {
                    Text("Reporting...")
                    Spacer()
                    ProgressView()
                  }
                } else {
                  Label("Report", systemImage: "exclamationmark.triangle")
                    .foregroundColor(.red)
                }
              }
              .disabled(isReporting)
            }
          }
        },
        label: {
          Image(systemName: "ellipsis")
            .font(.system(size: 22))
            .frame(width: 48, height: 40)
        }
      )

      if !isStandalone {
        Divider()
          .padding(.vertical, 5)
          .padding(.horizontal, 4)

        Button(action: {
          isShowingComments = true
        }) {
          ZStack {
            Image(systemName: "bubble.middle.bottom")
              .font(.system(size: 22))
              .frame(width: 48, height: 40)

            if post.commentCount > 0 {
              Text(post.commentCount > 9 ? "9+" : "\(post.commentCount)")
                .font(.caption2)
                .fontWeight(.medium)
                .padding(.bottom, 4)
            }
          }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact, trigger: isShowingComments)

        Divider()
          .padding(.vertical, 5)
          .padding(.horizontal, 4)
      }

      Button(action: {
        onLikeButtonTapped()
        PostHogSDK.shared.capture("post_like")
      }) {
        Image(systemName: post.isLiked ? "heart.fill" : "heart")
          .font(.system(size: 22))
          .foregroundStyle(
            post.isLiked ? Color.red.gradient : Color.primary.gradient
          )
          .frame(width: 48, height: 40)
          .scaleEffect(post.isLiked ? 1.1 : 1.0)
          .animation(
            .spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0),
            value: post.isLiked
          )
      }
      .sensoryFeedback(.impact, trigger: post.isLiked)

    }
    .fixedSize()
    .buttonStyle(.plain)
    .padding(3)
    .background {
      if #available(iOS 26.0, *) {
        Color.clear
      } else {
        RoundedRectangle(cornerRadius: 12).fill(.gray.opacity(0.15))
      }
    }
  }
}
