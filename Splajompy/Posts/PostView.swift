import Foundation
import SwiftUI

struct PostView: View {
  let post: DetailedPost
  var showAuthor: Bool = true
  var isStandalone: Bool = false
  let formatter = RelativeDateTimeFormatter()
  var onLikeButtonTapped: () -> Void = {
    print("Unimplemented: PostView.onLikeButtonTapped")
  }

  @State private var isShowingComments = false
  @EnvironmentObject private var feedRefreshManager: FeedRefreshManager
  @EnvironmentObject private var authManager: AuthManager

  private var postDate: Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.date(from: post.post.createdAt) ?? Date()
  }

  var body: some View {
    Group {
      if !isStandalone {
        NavigationLink {
          StandalonePostView(postId: post.id)
        } label: {
          postContent
        }
        .buttonStyle(.plain)
      } else {
        postContent
      }
    }
  }

  private var postContent: some View {
    VStack(alignment: .leading, spacing: 12) {
      if showAuthor {
        HStack(alignment: .top) {
          NavigationLink {
            ProfileView(
              userId: post.user.userId,
              username: post.user.username
            )
            .environmentObject(feedRefreshManager)
            .environmentObject(authManager)
          } label: {
            VStack(alignment: .leading, spacing: 2) {

              if post.user.username == "ads" {
                HStack {
                  Image(systemName: "medal")
                  Text("Sponsored")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                }
              } else {
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
            .backgroundStyle(.red)
          }
          .foregroundColor(.primary)
        }
      }
      if let postText = post.post.text, postText.count > 0 {
        ContentTextView(text: postText, facets: post.post.facets ?? [])
          .environmentObject(feedRefreshManager)
      }
      if let images = post.images, !images.isEmpty {
        ImageGallery(imageUrls: images.map { $0.imageBlobUrl })
      }
      HStack {
        Text(formatter.localizedString(for: postDate, relativeTo: Date()))
          .font(.caption)
          .foregroundColor(.gray)
        Spacer()
        HStack(spacing: 16) {
          if !isStandalone {
            Button(action: {
              isShowingComments = true
              let impact = UIImpactFeedbackGenerator(style: .light)
              impact.impactOccurred()
            }) {
              ZStack {
                Image(systemName: "bubble.middle.bottom")
                  .font(.system(size: 25))
                  .fontWeight(.light)

                if post.commentCount > 0 {
                  Text(post.commentCount > 9 ? "9+" : "\(post.commentCount)")
                    .font(.subheadline)
                    .padding(.bottom, 4)
                }
              }
            }
            .buttonStyle(.plain)
          }

          Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            onLikeButtonTapped()
          }) {
            HStack(spacing: 4) {
              Image(systemName: post.isLiked ? "heart.fill" : "heart")
                .font(.system(size: 26))
                .fontWeight(.light)
            }
          }
          .buttonStyle(.plain)
        }
      }

      RelevantLikeView(relevantLikes: post.relevantLikes, hasOtherLikes: post.hasOtherLikes)
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
      "This is a sample post with some text content. also here's a link: https://google.com, another link: splajompy.com",
    createdAt: "2025-04-01T12:30:45.123Z", facets: nil
  )

  let user = User(
    userId: 456,
    email: "wesleynw@pm.me",
    username: "wesleynw",
    createdAt: "2025-01-15T10:20:30.000Z",
    name: "John Doe"
  )

  let images = [
    ImageDTO(
      imageId: 789,
      postId: 123,
      height: 800,
      width: 1200,
      imageBlobUrl:
        "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
      displayOrder: 0
    ),
    ImageDTO(
      imageId: 790,
      postId: 123,
      height: 800,
      width: 1200,
      imageBlobUrl:
        "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
      displayOrder: 1
    ),
  ]

  let detailedPost = DetailedPost(
    post: post,
    user: user,
    isLiked: false,
    commentCount: 0,
    images: images,
    relevantLikes: [],
    hasOtherLikes: false
  )

  let feedRefreshManager = FeedRefreshManager()
  let authManager = AuthManager()

  NavigationView {
    PostView(post: detailedPost)
      .environmentObject(feedRefreshManager)
      .environmentObject(authManager)
  }
}

#Preview("Standalone") {
  let post = Post(
    postId: 123,
    userId: 456,
    text:
      "This is a sample post with some text content. also here's a link: https://google.com, another link: splajompy.com",
    createdAt: "2025-04-01T12:30:45.123Z",
    facets: nil
  )

  let user = User(
    userId: 456,
    email: "wesleynw@pm.me",
    username: "wesleynw",
    createdAt: "2025-01-15T10:20:30.000Z",
    name: "John Doe"
  )

  let images = [
    ImageDTO(
      imageId: 789,
      postId: 123,
      height: 800,
      width: 1200,
      imageBlobUrl:
        "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
      displayOrder: 0
    ),
    ImageDTO(
      imageId: 790,
      postId: 123,
      height: 800,
      width: 1200,
      imageBlobUrl:
        "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
      displayOrder: 1
    ),
  ]

  let detailedPost = DetailedPost(
    post: post,
    user: user,
    isLiked: false,
    commentCount: 0,
    images: images,
    relevantLikes: [],
    hasOtherLikes: false
  )

  let feedRefreshManager = FeedRefreshManager()
  let authManager = AuthManager()

  NavigationView {
    PostView(post: detailedPost, isStandalone: true)
      .environmentObject(feedRefreshManager)
      .environmentObject(authManager)
  }
}
