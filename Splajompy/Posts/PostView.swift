import Foundation
import PostHog
import SwiftUI

struct PostView: View {
  let post: DetailedPost
  let postManager: PostManager
  var showAuthor: Bool
  var isStandalone: Bool

  init(
    post: DetailedPost,
    postManager: PostManager,
    showAuthor: Bool = true,
    isStandalone: Bool = false,
    onLikeButtonTapped: @escaping () -> Void = {
      print("Unimplemented: PostView.onLikeButtonTapped")
    },
    onPostDeleted: @escaping () -> Void = {
      print("Unimplemented: PostView.onPostDeleted")
    },
    onPostPinned: @escaping () -> Void = {
      print("Unimplemented: PostView.onPostPinned")
    },
    onPostUnpinned: @escaping () -> Void = {
      print("Unimplemented: PostView.onPostUnpinned")
    }
  ) {
    self.post = post
    self.postManager = postManager
    self.showAuthor = showAuthor
    self.isStandalone = isStandalone
    self.onLikeButtonTapped = onLikeButtonTapped
    self.onPostDeleted = onPostDeleted
    self.onPostPinned = onPostPinned
    self.onPostUnpinned = onPostUnpinned
  }

  var onLikeButtonTapped: () -> Void
  var onPostDeleted: () -> Void
  var onPostPinned: () -> Void
  var onPostUnpinned: () -> Void

  @State private var isShowingComments = false
  @State private var isReporting = false
  @State private var showReportAlert = false
  @EnvironmentObject private var authManager: AuthManager

  // Cached formatter to avoid recreation on every render
  private static let dateFormatter = RelativeDateTimeFormatter()

  var body: some View {
    VStack(spacing: 0) {
      Divider()

      if !isStandalone {
        NavigationLink(value: Route.post(id: post.id)) {
          postContent
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 2)
        .padding(.vertical, 4)
      } else {
        postContent
          .padding(.horizontal, 2)
          .padding(.vertical, 4)
      }

      Divider()
    }
  }

  private var postContent: some View {
    VStack(alignment: .leading, spacing: 12) {
      if showAuthor {
        PostAuthorView(user: post.user)
      }

      if post.isPinned && !showAuthor {
        HStack {
          Image(systemName: "pin.fill")
            .font(.callout)
            .foregroundColor(.secondary)
          Text("Pinned")
            .font(.callout)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
          Spacer()
        }
        .transition(.opacity)
      }

      if let text = post.post.text, !text.isEmpty {
        ContentTextView(text: text, facets: post.post.facets ?? [])
      }

      if let images = post.images, !images.isEmpty {
        ImageGallery(images: images)
      }

      if let poll = post.poll {
        PollView(
          poll: poll,
          authorId: post.user.userId,
          onVote: { option in
            Task {
              await postManager.voteInPoll(postId: post.id, optionIndex: option)
            }
          }
        )
      }

      RelevantLikeView(
        relevantLikes: post.relevantLikes,
        hasOtherLikes: post.hasOtherLikes
      )

      HStack {
        Text(
          Self.dateFormatter.localizedString(
            for: post.post.createdAt,
            relativeTo: Date.now
          )
        )
        .font(.caption)
        .foregroundColor(.gray)
        Spacer()

        PostMenuView(
          post: post,
          showAuthor: showAuthor,
          isStandalone: isStandalone,
          onLikeButtonTapped: onLikeButtonTapped,
          onPostDeleted: onPostDeleted,
          onPostPinned: onPostPinned,
          onPostUnpinned: onPostUnpinned,
          isShowingComments: $isShowingComments,
          isReporting: $isReporting,
          showReportAlert: $showReportAlert
        )
      }
    }
    .padding(.vertical, 4)
    .padding(.horizontal, 16)
    .animation(.easeInOut(duration: 0.3), value: post.isPinned)
    .animation(.easeInOut(duration: 0.3), value: post.relevantLikes.count)
    .animation(.easeInOut(duration: 0.3), value: post.hasOtherLikes)
    .sheet(isPresented: $isShowingComments) {
      CommentsView(postId: post.post.postId, postManager: postManager)
    }
    .alert("Post Reported", isPresented: $showReportAlert) {
      Button("OK") {}
    } message: {
      Text("Thanks. A notification has been sent to the developer.")
    }
  }
}

#Preview {
  let post = Post(
    postId: 123,
    userId: 456,
    text:
      "This is a sample post with some text content. also here's a link: https://google.com, another link: splajompy.com",
    createdAt: ISO8601DateFormatter().date(from: "2025-04-01T12:30:45.123Z")!,
    facets: nil
  )

  let user = User(
    userId: 456,
    email: "wesleynw@pm.me",
    username: "wesleynw",
    createdAt: ISO8601DateFormatter().date(from: "2025-01-15T10:20:30.000Z")!,
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
    hasOtherLikes: false,
    isPinned: false
  )

  let authManager = AuthManager()
  let postManager = PostManager()

  NavigationStack {
    PostView(
      post: detailedPost,
      postManager: postManager,
      onLikeButtonTapped: {},
      onPostDeleted: {},
      onPostPinned: {},
      onPostUnpinned: {},
    )
    .environmentObject(authManager)
  }
}

#Preview("Standalone") {
  let post = Post(
    postId: 123,
    userId: 456,
    text:
      "This is a sample post with some text content. also here's a link: https://google.com, another link: splajompy.com",
    createdAt: ISO8601DateFormatter().date(from: "2025-04-01T12:30:45.123Z")!,
    facets: nil
  )

  let user = User(
    userId: 456,
    email: "wesleynw@pm.me",
    username: "wesleynw",
    createdAt: ISO8601DateFormatter().date(from: "2025-01-15T10:20:30.000Z")!,
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
    hasOtherLikes: false,
    isPinned: false
  )

  let authManager = AuthManager()
  let postManager = PostManager()

  NavigationView {
    PostView(
      post: detailedPost,
      postManager: postManager,
      onLikeButtonTapped: {},
      onPostDeleted: {},
      onPostPinned: {},
      onPostUnpinned: {}
    )
    .environmentObject(authManager)
  }
}
