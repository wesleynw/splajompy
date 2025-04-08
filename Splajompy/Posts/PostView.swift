import Foundation
import SwiftUI

struct PostView: View {
  let post: DetailedPost
  var showAuthor: Bool = true
  let formatter = RelativeDateTimeFormatter()
  var onLikeButtonTapped: () -> Void = { print("Unimplemented: PostView.onDeleteButtonTapped") }

  @State private var isShowingComments = false
  @EnvironmentObject private var feedRefreshManager: FeedRefreshManager
  @EnvironmentObject private var authManager: AuthManager

  private var postDate: Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.date(from: post.post.createdAt) ?? Date()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      if showAuthor {
        HStack(alignment: .top) {
          NavigationLink {
            ProfileView(userId: post.user.userId, username: post.user.username)
              .environmentObject(feedRefreshManager)
              .environmentObject(authManager)
          } label: {
            VStack(alignment: .leading, spacing: 2) {
              if let displayName = post.user.name, !displayName.isEmpty {
                Text(displayName)
                  .font(.title2)
                  .fontWeight(.black)
                  .lineLimit(1)
                Text("@\(post.user.username)")
                  .font(.subheadline)
                  .fontWeight(.bold)
                  .foregroundColor(.gray)
              } else {
                Text("@\(post.user.username)")
                  .font(.title3)
                  .fontWeight(.black)
                  .foregroundColor(.gray)
              }
            }
          }
          .foregroundColor(.primary)
          Spacer()
          // TODO
          // Image(systemName: "ellipsis")
        }
      }
      if let postText = post.post.text {
        //        Text(postText)
        //          .font(.body)
        //          .multilineTextAlignment(.leading)
        PostTextView(text: postText)
          .environmentObject(feedRefreshManager)
      }
      if let images = post.images, !images.isEmpty {
        ImageCarousel(imageUrls: images.map { $0.imageBlobUrl })
      }
      HStack {
        Text(formatter.localizedString(for: postDate, relativeTo: Date()))
          .font(.caption)
          .foregroundColor(.gray)
        Spacer()
        HStack(spacing: 16) {
          Button(action: {
            isShowingComments = true
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
          }) {
            HStack(spacing: 4) {
              Text("\(post.commentCount)")
                .font(.subheadline)
              Image(systemName: "bubble.right")
                .font(.system(size: 20))
            }
          }
          .buttonStyle(.plain)

          Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            onLikeButtonTapped()
          }) {
            HStack(spacing: 4) {
              Image(systemName: post.isLiked ? "heart.fill" : "heart")
                .font(.system(size: 20))
            }
          }
          .buttonStyle(.plain)
        }
      }
    }
    .padding(.vertical)
    .padding(.horizontal, 16)
    .overlay(
      Rectangle()
        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        .mask(
          VStack(spacing: 0) {
            Rectangle().frame(height: 1)
            Spacer()
            Rectangle().frame(height: 1)
          }
        )
    )
    .sheet(isPresented: $isShowingComments) {
      CommentsView(postId: post.post.postId)
    }
  }
}

#Preview {
  let post = Post(
    postId: 123,
    userId: 456,
    text:
      "This is a sample post with some interesting content. Check out these amazing images I captured during my recent trip!",
    createdAt: "2025-04-01T12:30:45.123Z"
  )

  let user = User(
    userId: 456,
    email: "john.doe@example.com",
    username: "johndoe",
    createdAt: "2025-01-15T10:20:30.000Z",
    name: "John Doe"
  )

  let images = [
    ImageDTO(
      imageId: 789,
      postId: 123,
      height: 800,
      width: 1200,
      imageBlobUrl: "https://example.com/image1",
      displayOrder: 0
    ),
    ImageDTO(
      imageId: 790,
      postId: 123,
      height: 800,
      width: 1200,
      imageBlobUrl: "https://example.com/image2",
      displayOrder: 1
    ),
  ]

  let detailedPost = DetailedPost(
    post: post,
    user: user,
    isLiked: false,
    commentCount: 5,
    images: images
  )

  // Mock components needed for preview
  struct ImageCarousel: View {
    let imageUrls: [String]

    var body: some View {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(imageUrls, id: \.self) { url in
            RoundedRectangle(cornerRadius: 8)
              .fill(Color.gray.opacity(0.3))
              .frame(width: 200, height: 150)
              .overlay(
                Text("Image")
                  .foregroundColor(.gray)
              )
          }
        }
      }
    }
  }

  struct ProfileView: View {
    let userId: Int
    let username: String
    let isOwnProfile: Bool

    var body: some View {
      Text("Profile for @\(username)")
    }
  }

  struct CommentsView: View {
    let postId: Int

    var body: some View {
      Text("Comments for post \(postId)")
    }
  }

  // UIKit mock for preview
  class UIImpactFeedbackGenerator {
    enum FeedbackStyle {
      case light
    }

    init(style: FeedbackStyle) {}

    func impactOccurred() {
      // Placeholder for haptic feedback
    }
  }

  return NavigationView {
    PostView(post: detailedPost)
  }
}
