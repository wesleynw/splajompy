import Foundation
import PostHog
import SwiftUI

struct ReelsPostView: View {
  let post: DetailedPost
  let formatter = RelativeDateTimeFormatter()
  var onLikeButtonTapped: () -> Void = {}
  var onPostDeleted: () -> Void = {}
  var onCommentsButtonTapped: () -> Void = {}

  @State private var isShowingComments = false
  @State private var isShowingPostMenu = false
  @State private var isTextExpanded = false
  @EnvironmentObject private var feedRefreshManager: FeedRefreshManager
  @EnvironmentObject private var authManager: AuthManager

  private var postDate: Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.date(from: post.post.createdAt) ?? Date()
  }

  var body: some View {
    ZStack {
      VStack {
        Spacer()
        contentView
        Spacer()
        bottomOverlay
          .padding(.bottom, 20)
      }
    }
    .sheet(isPresented: $isShowingComments) {
      CommentsView(postId: post.post.postId)
    }
    .sheet(isPresented: $isShowingPostMenu) {
      List {
        Button(action: { onPostDeleted() }) {
          Label("Delete", systemImage: "trash")
            .foregroundColor(.red)
        }
      }
      .presentationDetents([.medium])
      .presentationDragIndicator(.visible)
    }
  }

  @ViewBuilder
  private var contentView: some View {
    VStack(spacing: 12) {
      if let images = post.images, !images.isEmpty {
        ImageGallery(imageUrls: images.map { $0.imageBlobUrl })
          .clipShape(RoundedRectangle(cornerRadius: 12))
          .aspectRatio(contentMode: .fit)
      }
    }
    .padding(.horizontal, 16)
  }

  private var bottomOverlay: some View {
    HStack(alignment: .bottom) {
      VStack(alignment: .leading, spacing: 8) {
        NavigationLink(
          value: Route.profile(
            id: String(post.user.userId),
            username: post.user.username
          )
        ) {
          VStack(alignment: .leading, spacing: 2) {
            if let displayName = post.user.name, !displayName.isEmpty {
              Text(displayName)
                .font(.headline)
                .fontWeight(.bold)
            }
            Text("@\(post.user.username)")
              .font(.subheadline)
              .foregroundColor(.gray)
          }
        }
        .buttonStyle(.plain)

        if let postText = post.post.text, !postText.isEmpty {
          VStack(alignment: .leading, spacing: 4) {
            Text(postText)
              .font(.callout)
              .foregroundColor(.primary)
              .lineLimit(isTextExpanded ? nil : 10)
              .multilineTextAlignment(.leading)

            if postText.count > 50 {  // Show button only if text is long
              Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                  isTextExpanded.toggle()
                }
              }) {
                Text(isTextExpanded ? "Show less" : "Show more")
                  .font(.caption)
                  .foregroundColor(.gray)
              }
            }
          }
        }

        Text(formatter.localizedString(for: postDate, relativeTo: Date()))
          .font(.caption)
          .foregroundColor(.gray)
      }

      Spacer()

      VStack(spacing: 16) {
        VStack(spacing: 4) {
          Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            onLikeButtonTapped()
            PostHogSDK.shared.capture("post_like")
          }) {
            Image(systemName: post.isLiked ? "heart.fill" : "heart")
              .font(.title)
              .foregroundColor(post.isLiked ? .red : .primary)
          }
          .buttonStyle(.plain)
        }

        VStack(spacing: 4) {
          Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            isShowingComments = true
            onCommentsButtonTapped()
          }) {
            Image(systemName: "bubble.right")
              .font(.title)
              .foregroundColor(.primary)
          }
          .buttonStyle(.plain)

          if post.commentCount > 0 {
            Text("\(post.commentCount)")
              .font(.caption)
          }
        }

        if let currentUser = authManager.getCurrentUser() {
          if currentUser.userId == post.user.userId {
            Button(action: {
              isShowingPostMenu = true
            }) {
              Image(systemName: "ellipsis")
                .font(.title)
                .foregroundColor(.primary)
            }
            .buttonStyle(.plain)
          }
        }
      }
    }
    .padding(.horizontal, 16)
  }
}
