import PostHog
import SwiftUI

struct ProfileView: View {
  let username: String?
  let userId: Int
  let isProfileTab: Bool

  @State private var isPresentingProfileEditor: Bool = false
  @State private var viewModel: ViewModel
  @Environment(AuthManager.self) private var authManager
  var postManager: PostStore

  private var isProfileSelf: Bool {
    authManager.currentUser?.userId == self.userId
  }

  private var computedTitle: String {
    if let username = username {
      return "@" + username
    }

    switch viewModel.profileState {
    case .loaded(let user, _):
      return "@" + user.username
    default:
      return ""
    }
  }

  init(
    userId: Int,
    username: String?,
    postManager: PostStore,
    isProfileTab: Bool = false,
    viewModel: ViewModel? = nil
  ) {
    self.userId = userId
    self.username = username
    self.isProfileTab = isProfileTab
    self.postManager = postManager
    _viewModel = State(
      wrappedValue: viewModel
        ?? ViewModel(userId: userId, postManager: postManager)
    )
  }

  var body: some View {
    ScrollViewReader { proxy in  // TODO: refactor to .scrollPosition when dropping ios 17
      ScrollView {
        if case .loaded(let user, let feedState) = viewModel.profileState {
          profile(user: user, feedState: feedState, proxy: proxy)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .overlay {
        switch viewModel.profileState {
        case .idle, .loading:
          ProgressView()
            #if os(macOS)
              .controlSize(.small)
            #endif
        case .failed(let error):
          ErrorScreen(
            errorString: error,
            source: "ProfileView",
            onRetry: {
              await viewModel.loadProfileAndPosts(reset: false)
            }
          )
        default:
          EmptyView()
        }
      }
      .refreshable {
        await Task {
          await viewModel.loadProfileAndPosts()
        }.value
      }
    }
    .pageTitle(
      computedTitle,
      placement: .leading,
      font: isProfileTab ? SJFont.title : SJFont.heading,
    )
    .toolbar {
      if !isProfileSelf {
        profileActionsToolbar()
      }
    }
    .task {
      if case .idle = viewModel.profileState {
        await viewModel.loadProfileAndPosts()
      }
    }
    .sheet(isPresented: $isPresentingProfileEditor) {
      ProfileEditorView(viewModel: viewModel)
        .postHogScreenView()
        .interactiveDismissDisabled()
    }
  }

  @ToolbarContentBuilder
  private func profileActionsToolbar() -> some ToolbarContent {
    ToolbarItem(
      placement: {
        #if os(iOS)
          .automatic
        #else
          .primaryAction
        #endif
      }()
    ) {
      if case .loaded(let user, _) = viewModel.profileState {
        ProfileActionsMenu(
          isBlocking: user.isBlocking,
          isMuting: user.isMuting,
          username: user.username,
          onToggleBlock: viewModel.toggleBlocking,
          onToggleMute: viewModel.toggleMuting
        )
      } else {
        Menu {
          EmptyView()
        } label: {
          Image(systemName: "ellipsis.circle")
        }
        .disabled(true)
      }
    }
  }

  private func profile(
    user: DetailedUser,
    feedState: FeedState,
    proxy: ScrollViewProxy
  )
    -> some View
  {
    LazyVStack(spacing: 0) {
      profileHeader(user: user)

      switch feedState {
      case .idle, .loading:
        ProgressView()
      case .loaded(let posts):
        if posts.isEmpty {
          emptyMessage
        } else {
          postsContent(posts: posts, scrollProxy: proxy)
        }
      case .failed(let error):
        ErrorScreen(
          errorString: error.localizedDescription,
          source: "ProfileView",
          onRetry: { await viewModel.loadPosts(reset: true) }
        )
      }
    }
    #if os(macOS)
      .frame(maxWidth: 600)
      .frame(maxWidth: .infinity)
    #endif
    .refreshable {
      await Task {
        await viewModel.loadProfileAndPosts()
      }.value
    }
  }

  @ViewBuilder
  private func postsContent(
    posts: [ObservablePost],
    scrollProxy: ScrollViewProxy
  )
    -> some View
  {
    ForEach(Array(posts.enumerated()), id: \.element.id) {
      index,
      post in
      PostView(
        post: post,
        showAuthor: false,
        postManager: postManager,
        onLikeButtonTapped: { viewModel.toggleLike(on: post) },
        onPostDeleted: { viewModel.deletePost(on: post) },
        onPostPinned: {
          viewModel.pinPost(post)
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation {
              scrollProxy.scrollTo(post.id, anchor: .top)
            }
          }
        },
        onPostUnpinned: {
          viewModel.unpinPost(post)
        }
      )
      .id(post.id)
      .geometryGroup()
      .onAppear {
        viewModel.handlePostAppear(at: index, totalCount: posts.count)
      }
    }

    if viewModel.canLoadMorePosts {
      ProgressView()
        .frame(maxWidth: .infinity, alignment: .center)
    }
  }

  private func profileHeader(user: DetailedUser) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      ProfileDisplayNameView(user: user, largeTitle: true, showUsername: false)

      if !user.bio.isEmpty {
        Text(.init(user.bio))
          .font(.body)
          .fixedSize(horizontal: false, vertical: true)
      }

      if !isProfileTab && !isProfileSelf && user.isMuting {
        MutedIndicationView()
      }

      if !isProfileSelf {
        RelationshipIndicator(user: user)
      }

      if !isProfileSelf {
        if !user.isBlocking {
          if user.isFollowing {
            Button(action: viewModel.toggleFollowing) {
              if viewModel.isLoadingFollowButton {
                ProgressView()
                  .frame(maxWidth: .infinity)
              } else {
                Text("Unfollow")
                  .frame(maxWidth: .infinity)
              }
            }
            .modify {
              if #available(iOS 26, macOS 26, *) {
                $0.buttonStyle(.glass)
              } else {
                $0.buttonStyle(.bordered)
              }
            }
          } else {
            Button(action: viewModel.toggleFollowing) {
              if viewModel.isLoadingFollowButton {
                ProgressView()
                  .frame(maxWidth: .infinity)
              } else {
                Text("Follow")
                  .frame(maxWidth: .infinity)
              }
            }
            .modify {
              if #available(iOS 26, macOS 26, *) {
                $0.buttonStyle(.glassProminent)
              } else {
                $0.buttonStyle(.borderedProminent)
              }
            }
          }
        } else {
          Button(action: { viewModel.toggleBlocking() }) {
            Text("Unblock")
              .frame(maxWidth: .infinity)
              .foregroundStyle(.red.opacity(0.7))
          }
          .buttonStyle(.bordered)
        }
      } else if isProfileTab && isProfileSelf {
        HStack(spacing: 12) {
          Button(action: { isPresentingProfileEditor = true }) {
            Text("Edit Profile")
              .frame(maxWidth: .infinity)
          }
          .modify {
            if #available(iOS 26, macOS 26, *) {
              $0.buttonStyle(.glass)
            } else {
              $0.buttonStyle(.bordered)
            }
          }

          NavigationLink(value: Route.followingList(userId: userId)) {
            Text("Following")
              .frame(maxWidth: .infinity)
          }
          .modify {
            if #available(iOS 26, macOS 26, *) {
              $0.buttonStyle(.glass)
            } else {
              $0.buttonStyle(.bordered)
            }
          }
        }

      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
  }

  private var emptyMessage: some View {
    Text(isProfileSelf ? "Your posts will show up here." : "No posts here.")
      .font(SJFont.callout)
      .frame(maxWidth: .infinity, alignment: .center)
      .padding(.top, 50)
  }
}

#Preview {
  let postManager = PostStore(postService: MockPostService())

  NavigationStack {
    ProfileView(
      userId: 1,
      username: "wesley",
      postManager: postManager,
      isProfileTab: true,
      viewModel: ProfileView.ViewModel(
        userId: 1,
        postManager: postManager,
        profileService: MockProfileService()
      )
    )
    .environment(AuthManager())
  }
}
