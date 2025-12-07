import SwiftUI

struct ProfileView: View {
  let username: String
  let userId: Int
  let isProfileTab: Bool

  @State private var isShowingProfileEditor: Bool = false
  @State private var activeAlert: ProfileAlertEnum?
  @StateObject private var viewModel: ViewModel
  @EnvironmentObject private var authManager: AuthManager
  @ObservedObject var postManager: PostManager

  private var isCurrentUser: Bool {
    guard let currentUser = authManager.getCurrentUser() else { return false }
    return currentUser.userId == userId
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
    username: String,
    postManager: PostManager,
    isProfileTab: Bool = false,
    viewModel: ViewModel? = nil
  ) {
    self.userId = userId
    self.username = username
    self.isProfileTab = isProfileTab
    self.postManager = postManager
    _viewModel = StateObject(
      wrappedValue: viewModel
        ?? ViewModel(userId: userId, postManager: postManager)
    )
  }

  var body: some View {
    Group {
      switch viewModel.profileState {
      case .idle, .loading:
        ProgressView()
      case .loaded(let user):
        profile(user: user)
      case .failed(let error):
        ErrorScreen(
          errorString: error,
          onRetry: { await viewModel.loadProfileAndPosts() }
        )
      }
    }
    .onAppear {
      Task {
        await viewModel.loadProfileAndPosts()
      }
    }
    .navigationTitle("@" + self.username)
    .sheet(isPresented: $isShowingProfileEditor) {
      ProfileEditorView(viewModel: viewModel)
        .interactiveDismissDisabled()
    }
    .toolbar {
      if !isProfileTab && !isCurrentUser {
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
              onRetry: { await viewModel.loadPosts(reset: true) }
            )
          }
        }
        #if os(macOS)
          .frame(maxWidth: 600)
          .frame(maxWidth: .infinity)
        #endif
      }
      .environmentObject(authManager)
      .refreshable {
        await viewModel.loadProfileAndPosts()
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
        postManager: postManager,
        showAuthor: false,
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
        Text(user.bio)
          .font(.body)
          .fixedSize(horizontal: false, vertical: true)
      }

      if !isProfileTab && !isCurrentUser && user.isMuting {
        HStack(spacing: 6) {
          Image(systemName: "speaker.slash.fill")
            .font(.system(size: 14))
            .foregroundColor(.secondary)
          Text("You have muted this person")
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(.thinMaterial)
        .cornerRadius(8)
      }

      if !isProfileTab && !isCurrentUser {
        RelationshipIndicator(user: user)
      }

      if !isProfileTab && !isCurrentUser {
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
      } else if isProfileTab && isCurrentUser {
        HStack(spacing: 12) {
          Button(action: { isShowingProfileEditor = true }) {
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
    VStack {
      Spacer()
      Text(isCurrentUser ? "Your posts will show up here." : "No posts here.")
        .padding()
      Spacer()
    }
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
  let postManager = PostManager(postService: MockPostService())

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
    .environmentObject(AuthManager())
  }
}


