import Foundation
import PostHog
import SwiftUI

struct PostView: View {
  let post: DetailedPost
  let postManager: PostManager
  var showAuthor: Bool
  var isStandalone: Bool

  init(
    post: DetailedPost, postManager: PostManager, showAuthor: Bool = false,
    isStandalone: Bool = false, onLikeButtonTapped: @escaping () -> Void,
    onPostDeleted: @escaping () -> Void
  ) {
    self.post = post
    self.postManager = postManager
    self.showAuthor = showAuthor
    self.isStandalone = isStandalone
    self.onLikeButtonTapped = onLikeButtonTapped
    self.onPostDeleted = onPostDeleted
  }

  var onLikeButtonTapped: () -> Void = {
    print("Unimplemented: PostView.onLikeButtonTapped")
  }
  var onPostDeleted: () -> Void = {
    print("Unimplemented: PostView.onPostDeleted")
  }

  @State private var isShowingComments = false
  @State private var isReporting = false
  @State private var showReportAlert = false
  @EnvironmentObject private var authManager: AuthManager

  var body: some View {
    Group {
      Divider()

      Group {
        if !isStandalone {
          NavigationLink(
            destination:
              StandalonePostView(postId: post.id, postManager: postManager)
          ) {
            postContent
          }
          .buttonStyle(.plain)
        } else {
          postContent
        }
      }
      .padding(.horizontal, 2)
      .padding(.vertical, 4)

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
                    .foregroundColor(.gray)
                }
              }
            }
          }
        }
        .buttonStyle(.plain)
      }

      if let content = post.post.richContent {
        ContentTextView(attributedText: content)
      }

      if let images = post.images, !images.isEmpty {
        ImageGallery(images: images)
      }
      
      if let poll = post.poll {
        PollView(poll: poll, onVote: { option in Task { await postManager.voteInPoll(postId: post.id, optionIndex: option) } })
      }

      RelevantLikeView(
        relevantLikes: post.relevantLikes,
        hasOtherLikes: post.hasOtherLikes
      )

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
        HStack(spacing: 8) {
          if !isStandalone {
            Menu(
              content: {
                if let currentUser = authManager.getCurrentUser() {
                  if currentUser.userId == post.user.userId {
                    Button(role: .destructive, action: { onPostDeleted() }) {
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
                #if os(iOS)
                  Image(systemName: "ellipsis")
                    .font(.system(size: 22))
                    .frame(width: 48, height: 40)
                    .background(
                      RoundedRectangle(cornerRadius: 12).fill(.gray.opacity(0.15))
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 12))
                #else
                  Image(systemName: "ellipsis")
                    .font(.system(size: 18))
                    .frame(width: 32, height: 32)
                    .background(
                      RoundedRectangle(cornerRadius: 6).fill(.gray.opacity(0.1))
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 6))
                #endif
              }
            )
            .accessibilityLabel("More options")

            Button(action: {
              isShowingComments = true
            }) {
              ZStack {
                #if os(iOS)
                  Image(systemName: "bubble.middle.bottom")
                    .font(.system(size: 22))
                    .frame(width: 48, height: 40)
                    .background(
                      RoundedRectangle(cornerRadius: 12).fill(.gray.opacity(0.15))
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 12))
                #else
                  Image(systemName: "bubble.middle.bottom")
                    .font(.system(size: 18))
                    .frame(width: 32, height: 32)
                    .background(
                      RoundedRectangle(cornerRadius: 6).fill(.gray.opacity(0.1))
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 6))
                #endif

                if post.commentCount > 0 {
                  Text(post.commentCount > 9 ? "9+" : "\(post.commentCount)")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.bottom, 4)
                }
              }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Comment on post")
            .sensoryFeedback(.impact, trigger: isShowingComments)
          }

          Button(action: {
            onLikeButtonTapped()
            PostHogSDK.shared.capture("post_like")
          }) {
            #if os(iOS)
              Image(systemName: post.isLiked ? "heart.fill" : "heart")
                .font(.system(size: 22))
                .foregroundColor(post.isLiked ? .red : .primary)
                .frame(width: 48, height: 40)
                .background(
                  RoundedRectangle(cornerRadius: 12).fill(.gray.opacity(0.15))
                )
                .contentShape(RoundedRectangle(cornerRadius: 12))
            #else
              Image(systemName: post.isLiked ? "heart.fill" : "heart")
                .font(.system(size: 18))
                .foregroundColor(post.isLiked ? .red : .primary)
                .frame(width: 32, height: 32)
                .background(
                  RoundedRectangle(cornerRadius: 6).fill(.gray.opacity(0.1))
                )
                .contentShape(RoundedRectangle(cornerRadius: 6))
            #endif
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Like post")
          .sensoryFeedback(.impact, trigger: post.isLiked)
        }
      }
    }
    .padding(.vertical, 4)
    #if os(iOS)
      .padding(.horizontal, 16)
    #else
      .padding(.horizontal, 24)
    #endif
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
    hasOtherLikes: false
  )

  let authManager = AuthManager()
  let postManager = PostManager()

  NavigationView {
    PostView(
      post: detailedPost, postManager: postManager, onLikeButtonTapped: {}, onPostDeleted: {}
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
    hasOtherLikes: false
  )

  let authManager = AuthManager()
  let postManager = PostManager()

  NavigationView {
    PostView(
      post: detailedPost, postManager: postManager, onLikeButtonTapped: {}, onPostDeleted: {}
    )
    .environmentObject(authManager)
  }
}
