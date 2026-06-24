import PostHog
import SwiftUI

struct PostView: View {
  @Bindable var post: ObservablePost
  var showAuthor: Bool = true
  var isStandalone: Bool = false
  var postManager: PostStore

  var onLikeButtonTapped: () -> Void
  var onPostDeleted: () -> Void
  var onPostPinned: (() -> Void)?
  var onPostUnpinned: (() -> Void)?

  init(
    post: ObservablePost,
    showAuthor: Bool = true,
    isStandalone: Bool = false,
    postManager: PostStore,
    onLikeButtonTapped: @escaping () -> Void,
    onPostDeleted: @escaping () -> Void,
    onPostPinned: (() -> Void)? = nil,
    onPostUnpinned: (() -> Void)? = nil
  ) {
    self.post = post
    self.showAuthor = showAuthor
    self.isStandalone = isStandalone
    self.postManager = postManager
    self.onLikeButtonTapped = onLikeButtonTapped
    self.onPostDeleted = onPostDeleted
    self.onPostPinned = onPostPinned
    self.onPostUnpinned = onPostUnpinned
  }

  @State private var isPresentingCommentsSheet: Bool = false

  var body: some View {
    Group {
      if isStandalone {
        postContent
      } else {
        NavigationLink(value: Route.post(id: post.id)) {
          postContent
        }
        .buttonStyle(.plain)
      }
    }
    .sheet(isPresented: $isPresentingCommentsSheet) {
      CommentsView(postId: post.post.postId, postManager: postManager)
        .postHogScreenView()
    }
  }

  private var postContent: some View {
    VStack {
      Divider()
        .padding(.bottom, 4)

      VStack(alignment: .leading, spacing: 10) {

        PostVisibilityIndicator(visibility: post.post.visibility)

        if showAuthor {
          authorHeader
        }

        if post.isPinned && !showAuthor {
          pinnedIndicator
        }

        postTextContent
        postImages
        postPoll
        relevantLikes
        postFooter

      }
      .padding(.vertical, 8)

      Divider()
    }
    .contentShape(Rectangle())
    .animation(.easeInOut(duration: 0.3), value: post.isPinned)
    .safeAreaPadding(.horizontal, 16)
  }

  private var authorHeader: some View {
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
            ProfileDisplayNameView(user: post.user, largeTitle: true)
          }
        }
      }
    }
    .buttonStyle(.plain)
  }

  private var pinnedIndicator: some View {
    HStack {
      Image(systemName: "pin.fill")
        .font(.callout)
        .foregroundStyle(.secondary)
      Text("Pinned")
        .font(.callout)
        .fontWeight(.semibold)
        .foregroundStyle(.secondary)
      Spacer()
    }
    .transition(.opacity)
  }

  @ViewBuilder
  private var postTextContent: some View {
    if let content = post.post.richContent {
      Text(content)
        .lineLimit(nil)
        // this is kind of a hack, for some reason the gallery keeps taking up extra space
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  @ViewBuilder
  private var postImages: some View {
    if let images = post.images, !images.isEmpty {
      ImageGallery(images: images)
    }
  }

  @ViewBuilder
  private var postPoll: some View {
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
  }

  private var relevantLikes: some View {
    RelevantLikeView(
      relevantLikes: post.relevantLikes,
      hasOtherLikes: post.hasOtherLikes
    )
    .animation(.easeInOut(duration: 0.3), value: post.relevantLikes.count)
    .animation(.easeInOut(duration: 0.3), value: post.hasOtherLikes)
  }

  private var postFooter: some View {
    HStack(alignment: .center) {
      TimelineView(.periodic(from: .now, by: 5)) { _ in
        Text(
          post.post.createdAt
            .formatted(.relative(presentation: .named))
        )
        .font(.caption)
        .foregroundStyle(.gray)
      }

      Spacer()

      postMenu
    }
  }

  @ViewBuilder
  private var postMenu: some View {
    HStack {
      if !isStandalone {
        PostActionMenu(
          post: post,
          showAuthor: showAuthor,
          onPostDeleted: onPostDeleted,
          onPostPinned: onPostPinned,
          onPostUnpinned: onPostUnpinned
        ) {
          Image(systemName: "ellipsis")
            .font(.system(size: 22))
            .frame(width: 48)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)

        Divider()
          .padding(.vertical, 5)
          .padding(.horizontal, 4)
      }

      if !isStandalone {
        #if os(iOS)
          Button(action: {
            isPresentingCommentsSheet = true
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
          .sensoryFeedback(.impact, trigger: isPresentingCommentsSheet)
        #else
          NavigationLink(value: Route.post(id: post.id)) {
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
        #endif

        Divider()
          .padding(.vertical, 5)
          .padding(.horizontal, 4)
      }

      LikeButtonView(
        isLiked: $post.isLiked,
        onLikeButtonTapped: onLikeButtonTapped
      )
    }
    .frame(height: 35)
  }

}

#Preview {
  let post = DetailedPost(
    post: Post(
      postId: 123,
      userId: 456,
      text:
        "Weclome to Splajompy!",
      createdAt: Date(),
      facets: nil
    ),
    user: PublicUser(
      userId: 456,
      username: "wesley",
      createdAt: Date(),
      name: "Wesley",
      isVerified: false,
      displayProperties: UserDisplayProperties(fontChoiceId: 1)
    ),
    isLiked: false,
    commentCount: 0,
    relevantLikes: [],
    hasOtherLikes: false,
    isPinned: false
  )

  NavigationStack {
    PostView(
      post: ObservablePost(from: post),
      postManager: PostStore(),
      onLikeButtonTapped: {},
      onPostDeleted: {},
      onPostPinned: {},
      onPostUnpinned: {}
    )
    .environment(AuthManager())
  }
}
