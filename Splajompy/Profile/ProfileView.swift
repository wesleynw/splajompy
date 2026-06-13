import PostHog
import SwiftUI

struct ProfileView: View {
  let username: String?
  let userId: Int
  let isProfileTab: Bool

  @State private var isPresentingProfileEditor: Bool = false
  @State private var activeAlert: ProfileAlertEnum?
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
    case .loaded(let user):
      return "@" + user.username
    default:
      return ""
    }
  }

  private var alertTitle: String {
    guard case .loaded(let user) = viewModel.profileState,
      let alertType = activeAlert
    else {
      return ""
    }

    switch alertType {
    case .block:
      return user.isBlocking
        ? "Unblock @\(user.username)" : "Block @\(user.username)"
    case .mute:
      return user.isMuting
        ? "Unmute @\(user.username)" : "Mute @\(user.username)"
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
    mainContent
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
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarRole(.browser)
      #endif
      .navigationTitle(computedTitle)
      .toolbar {
        #if os(iOS)
          titleToolbar()
        #endif

        if !isProfileSelf {
          profileActionsToolbar()
        }
      }
      .alert(
        alertTitle,
        isPresented: Binding(
          get: { activeAlert != nil },
          set: { if !$0 { activeAlert = nil } }
        ),
        presenting: activeAlert
      ) { alertType in
        switch alertType {
        case .block:
          if case .loaded(let user) = viewModel.profileState {
            if user.isBlocking {
              Button("Unblock") {
                viewModel.toggleBlocking()
              }
            } else {
              Button("Block", role: .destructive) {
                viewModel.toggleBlocking()
              }
            }
          }
          Button("Cancel", role: .cancel) {}
        case .mute:
          if case .loaded(let user) = viewModel.profileState {
            if user.isMuting {
              Button("Unmute") {
                viewModel.toggleMuting()
              }
            } else {
              Button("Mute", role: .destructive) {
                viewModel.toggleMuting()
              }
            }
          }
          Button("Cancel", role: .cancel) {}
        }
      } message: { alertType in
        if case .loaded(let user) = viewModel.profileState {
          switch alertType {
          case .block:
            if user.isBlocking {
              Text(
                "Unblocking this person will allow you to see their posts and interact with them again."
              )
            } else {
              Text(
                "Blocking this person will unfollow them and prevent you from seeing their posts. They will be unable to see your presence on the app."
              )
            }
          case .mute:
            if user.isMuting {
              Text(
                "Unmuting this person will show their posts in your feeds again."
              )
            } else {
              Text(
                "Muting this person will hide their posts from your feeds. You'll continue to follow them and they will not be aware that they are muted."
              )
            }
          }
        }
      }
  }

  @ViewBuilder
  private var mainContent: some View {
    switch viewModel.profileState {
    case .idle, .loading:
      ProgressView()
        #if os(macOS)
          .controlSize(.small)
        #endif
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    case .loaded(let user):
      profile(user: user)
    case .failed(let error):
      ErrorScreen(
        errorString: error,
        source: "ProfileView",
        onRetry: {
          await viewModel.loadProfileAndPosts(useLoadingState: false)
        }
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  #if os(iOS)
    @ToolbarContentBuilder
    private func titleToolbar() -> some ToolbarContent {
      if isProfileTab {
        if #available(iOS 26, *) {
          ToolbarItem(
            placement: .principal
          ) {
            Text(computedTitle)
              .font(.title2)
              .fontWeight(.black)
          }
          .sharedBackgroundVisibility(.hidden)
        } else {
          ToolbarItem(
            placement: .principal
          ) {
            HStack {
              Text(computedTitle)
                .font(.title2)
                .fontWeight(.black)

              Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
      } else {
        if #available(iOS 26, *) {
          ToolbarItem(placement: .principal) {
            Text(computedTitle)
              .font(.callout)
              .fontWeight(.bold)
          }
          .sharedBackgroundVisibility(.hidden)
        } else {
          ToolbarItem(placement: .principal) {
            Text(computedTitle)
              .font(.callout)
              .fontWeight(.bold)
          }
        }
      }
    }
  #endif

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
      Menu {
        if case .loaded(let user) = viewModel.profileState {
          if user.isBlocking {
            Button(role: .destructive, action: { activeAlert = .block }) {
              Label(
                "Unblock @\(user.username)",
                systemImage: "person.fill.checkmark"
              )
            }
          } else {
            Button(role: .destructive, action: { activeAlert = .block }) {
              Label(
                "Block @\(user.username)",
                systemImage: "person.fill.xmark"
              )
            }
          }

          if user.isMuting {
            Button(action: { activeAlert = .mute }) {
              Label(
                "Unmute @\(user.username)",
                systemImage: "speaker.wave.2"
              )
            }
          } else {
            Button(action: { activeAlert = .mute }) {
              Label(
                "Mute @\(user.username)",
                systemImage: "speaker.slash"
              )
            }
          }
        }
      } label: {
        Image(systemName: "ellipsis.circle")
      }
      .disabled(
        viewModel.isLoadingBlockButton || viewModel.isLoadingMuteButton
      )
    }
  }

  private func profile(user: DetailedUser)
    -> some View
  {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(spacing: 0) {
          profileHeader(user: user)

          switch viewModel.postsState {
          case .idle, .loading:
            ProgressView()
          case .loaded(let postIds):
            if postIds.isEmpty {
              emptyMessage
            } else {
              postsContent(postIds: postIds, scrollProxy: proxy)
            }
          case .failed(let error):
            ErrorScreen(
              errorString: error,
              source: "ProfileView",
              onRetry: { await viewModel.loadPosts(reset: true) }
            )
          }
        }
        #if os(macOS)
          .frame(maxWidth: 600)
          .frame(maxWidth: .infinity)
        #endif
      }
      .refreshable {
        await Task {
          await viewModel.loadProfileAndPosts()
        }.value
      }
    }
  }

  @ViewBuilder
  private func postsContent(postIds: [Int], scrollProxy: ScrollViewProxy)
    -> some View
  {
    let posts = postManager.getPostsById(postIds)
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
        viewModel.handlePostAppear(at: index, totalCount: postIds.count)
      }
    }

    if viewModel.canLoadMorePosts {
      HStack {
        Spacer()
        ProgressView()
          .padding()
        Spacer()
      }
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
        HStack(spacing: 6) {
          Image(systemName: "speaker.slash.fill")
            .font(.system(size: 14))
            .foregroundStyle(.secondary)
          Text("You have muted this person")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(.thinMaterial)
        .cornerRadius(8)
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
          Button(action: { activeAlert = .block }) {
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
      .frame(maxWidth: .infinity, alignment: .center)
      .padding()
  }
}

enum ProfileAlertEnum: Identifiable {
  case block
  case mute

  var id: String {
    switch self {
    case .block: return "block"
    case .mute: return "mute"
    }
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
