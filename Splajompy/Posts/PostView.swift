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
  @State private var showDeleteConfirmation = false
  @EnvironmentObject private var authManager: AuthManager

  var body: some View {
    VStack {
      Divider()
      if !isStandalone {
        NavigationLink(
          value: Route.post(id: post.id)
        ) {
          postContent
        }
        .buttonStyle(.plain)
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
        HStack(alignment: .top) {
          NavigationLink(
            value: Route.profile(
              id: String(post.user.userId),
              username: post.user.username
            )
          ) {
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
                }
              }
            }
          }
        }
        .buttonStyle(.plain)
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

      if let content = post.post.richContent {
        ContentTextView(attributedText: content)
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
      .animation(.easeInOut(duration: 0.3), value: post.relevantLikes.count)
      .animation(.easeInOut(duration: 0.3), value: post.hasOtherLikes)

      HStack {
        Text(
          RelativeDateTimeFormatter().localizedString(
            for: post.post.createdAt,
            relativeTo: Date.now
          )
        )
        .font(.caption)
        .foregroundColor(.gray)
        Spacer()

        postMenu
      }
    }
    .animation(.easeInOut(duration: 0.3), value: post.isPinned)
    .padding(.vertical, 4)
    .padding(.horizontal, 16)
    .sheet(isPresented: $isShowingComments) {
      CommentsView(postId: post.post.postId, postManager: postManager)
    }
    .alert("Post Reported", isPresented: $showReportAlert) {
      Button("OK") {}
    } message: {
      Text("Thanks. A notification has been sent to the developer.")
    }
    .confirmationDialog(
      "Are you sure you want to delete this post?",
      isPresented: $showDeleteConfirmation,
      titleVisibility: .visible
    ) {
      Button("Delete", role: .destructive) {
        onPostDeleted()
      }
      Button("Cancel", role: .cancel) {}
    }
  }

  private var postMenu: some View {
    HStack(spacing: 2) {
      Menu(
        content: {
          if let currentUser = authManager.getCurrentUser() {
            if currentUser.userId == post.user.userId {
              if !showAuthor {
                if post.isPinned {
                  Button(action: {
                    onPostUnpinned()
                  }) {
                    Label("Unpin", systemImage: "pin.slash")
                  }
                } else {
                  Button(action: {
                    onPostPinned()
                  }) {
                    Label("Pin", systemImage: "pin")
                  }
                }
              }

              Button(role: .destructive, action: { showDeleteConfirmation = true }) {
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

      Divider()
        .padding(.vertical, 5)
        .padding(.horizontal, 4)

      if !isStandalone {
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
  }

}

#Preview {
  let dateFormatter = ISO8601DateFormatter()
  dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

  let post = Post(
    postId: 123,
    userId: 456,
    text:
      "This is a sample post with some text content. also here's a link: https://google.com, another link: splajompy.com",
    createdAt: dateFormatter.date(from: "2025-04-01T12:30:45.123Z")!,
    facets: nil
  )

  let user = User(
    userId: 456,
    email: "wesleynw@pm.me",
    username: "wesleynw",
    createdAt: dateFormatter.date(from: "2025-01-15T10:20:30.000Z")!,
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

  return NavigationStack {
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
  let dateFormatter = ISO8601DateFormatter()
  dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

  let post = Post(
    postId: 123,
    userId: 456,
    text:
      "This is a sample post with some text content. also here's a link: https://google.com, another link: splajompy.com",
    createdAt: dateFormatter.date(from: "2025-04-01T12:30:45.123Z")!,
    facets: nil
  )

  let user = User(
    userId: 456,
    email: "wesleynw@pm.me",
    username: "wesleynw",
    createdAt: dateFormatter.date(from: "2025-01-15T10:20:30.000Z")!,
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

  return NavigationStack {
    PostView(
      post: detailedPost,
      postManager: postManager,
      isStandalone: true,
      onLikeButtonTapped: {},
      onPostDeleted: {},
      onPostPinned: {},
      onPostUnpinned: {}
    )
    .environmentObject(authManager)
  }
}
