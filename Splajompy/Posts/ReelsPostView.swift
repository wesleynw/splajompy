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
  @EnvironmentObject private var feedRefreshManager: FeedRefreshManager
  @EnvironmentObject private var authManager: AuthManager

  private var postDate: Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.date(from: post.post.createdAt) ?? Date()
  }

  var body: some View {
    ZStack {
      // Simple black background
      Rectangle()
        .fill(Color.black)

      // Content layout
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

      if let postText = post.post.text, !postText.isEmpty {
        let hasImages = post.images != nil && !post.images!.isEmpty

        ScrollView {
          ContentTextView(text: postText, facets: post.post.facets ?? [])
            .environmentObject(feedRefreshManager)
            .foregroundColor(.white)
            .font(.body)
            .multilineTextAlignment(.center)
        }
        .frame(maxHeight: hasImages ? 120 : 300)
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
                .foregroundColor(.white)
            }
            Text("@\(post.user.username)")
              .font(.subheadline)
              .foregroundColor(.white.opacity(0.8))
          }
        }
        .buttonStyle(.plain)

        if let postText = post.post.text, !postText.isEmpty {
          Text(postText)
            .font(.callout)
            .foregroundColor(.white.opacity(0.9))
            .lineLimit(3)
            .multilineTextAlignment(.leading)
        }

        Text(formatter.localizedString(for: postDate, relativeTo: Date()))
          .font(.caption)
          .foregroundColor(.white.opacity(0.6))
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
              .foregroundColor(post.isLiked ? .red : .white)
              .frame(width: 44, height: 44)
              .background(
                Circle()
                  .fill(Color.black.opacity(0.3))
              )
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
              .foregroundColor(.white)
              .frame(width: 44, height: 44)
              .background(
                Circle()
                  .fill(Color.black.opacity(0.3))
              )
          }
          .buttonStyle(.plain)

          if post.commentCount > 0 {
            Text("\(post.commentCount)")
              .font(.caption)
              .foregroundColor(.white)
          }
        }

        if authManager.getCurrentUser().userId == post.user.userId {
          Button(action: {
            isShowingPostMenu = true
          }) {
            Image(systemName: "ellipsis")
              .font(.title)
              .foregroundColor(.white)
              .frame(width: 44, height: 44)
              .background(
                Circle()
                  .fill(Color.black.opacity(0.3))
              )
          }
          .buttonStyle(.plain)
        }
      }
    }
    .padding(.horizontal, 16)
  }
}
