import SwiftUI

struct ProfileView: View {
  let username: String
  let userId: Int
  let isProfileTab: Bool

  @State private var isShowingProfileEditor: Bool = false
  @StateObject private var viewModel: ViewModel
  @EnvironmentObject private var authManager: AuthManager
  @ObservedObject var postManager: PostManager

  private var isCurrentUser: Bool {
    guard let currentUser = authManager.getCurrentUser() else { return false }
    return currentUser.userId == userId
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
        loadingPlaceholder
      case .loaded(let user):
        profileList(user: user)
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
              Button(role: .destructive, action: viewModel.toggleBlocking) {
                Label(
                  "Unblock @\(user.username)",
                  systemImage: "person.fill.checkmark"
                )
              }
            } else {
              Button(role: .destructive, action: viewModel.toggleBlocking) {
                Label(
                  "Block @\(user.username)",
                  systemImage: "person.fill.xmark"
                )
              }
            }
          }
        } label: {
          Image(systemName: "ellipsis.circle")
        }
        .disabled(viewModel.isLoadingBlockButton)
      }
    }
  }

  private func profileList(user: UserProfile)
    -> some View
  {
    ScrollView {
      LazyVStack(spacing: 0) {
        profileHeader(user: user)

        switch viewModel.postsState {
        case .idle, .loading:
          loadingPlaceholder
        case .loaded(let postIds):
          if postIds.isEmpty {
            emptyMessage
          } else {
            postsContent(postIds: postIds)
          }
        case .failed(let error):
          ErrorScreen(
            errorString: error,
            onRetry: { await viewModel.loadPosts(reset: true) }
          )
        }
      }
    }
    .environmentObject(authManager)
    .refreshable {
      await viewModel.loadPosts(reset: true)
    }
  }

  @ViewBuilder
  private func postsContent(postIds: [Int]) -> some View {
    let posts = postManager.getPostsById(postIds)
    ForEach(Array(posts.enumerated()), id: \.element.id) {
      index,
      post in
      PostView(
        post: post,
        postManager: postManager,
        showAuthor: false,
        onLikeButtonTapped: { viewModel.toggleLike(on: post) },
        onPostDeleted: { viewModel.deletePost(on: post) }
      )
      .geometryGroup()
      .onAppear {
        handlePostAppear(post: post, index: index, totalCount: postIds.count)
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

  private func handlePostAppear(post: DetailedPost, index: Int, totalCount: Int) {
    if case .loaded = viewModel.profileState,
      case .loaded(_) = viewModel.postsState,
      index >= totalCount - 3 && viewModel.canLoadMorePosts
        && !viewModel.isLoadingMorePosts
    {
      Task {
        await viewModel.loadPosts()
      }
    }
  }

  private func profileHeader(user: UserProfile) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          if !user.name.isEmpty {
            Text(user.name)
              .font(.title2)
              .fontWeight(.bold)
              .lineLimit(1)
          }
        }
        Spacer()
      }

      if !user.bio.isEmpty {
        Text(user.bio)
          .font(.body)
          .fixedSize(horizontal: false, vertical: true)
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
            .buttonStyle(.bordered)
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
            .buttonStyle(.borderedProminent)
          }
        } else {
          Button(action: viewModel.toggleBlocking) {
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
          .buttonStyle(.bordered)

          NavigationLink(value: Route.followingList(userId: userId)) {
            Text("Following")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.bordered)
        }

      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
  }

  private var loadingPlaceholder: some View {
    VStack {
      Spacer()
      ProgressView()
        .scaleEffect(1.5)
        .padding()
      Spacer()
    }
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
