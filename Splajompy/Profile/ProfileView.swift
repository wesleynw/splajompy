import SwiftUI

struct ProfileView: View {
  let username: String
  let userId: Int
  let isProfileTab: Bool
  @ObservedObject var postManager: PostManager

  @State private var isShowingProfileEditor: Bool = false
  @StateObject private var viewModel: ViewModel
  @EnvironmentObject private var authManager: AuthManager

  private var isCurrentUser: Bool {
    guard let currentUser = authManager.getCurrentUser() else { return false }
    return currentUser.userId == userId
  }

  init(
    userId: Int,
    username: String,
    postManager: PostManager,
    isProfileTab: Bool = false
  ) {
    self.userId = userId
    self.username = username
    self.isProfileTab = isProfileTab
    self.postManager = postManager
    _viewModel = StateObject(
      wrappedValue: ViewModel(userId: userId, postManager: postManager)
    )
  }

  init(
    userId: Int,
    username: String,
    postManager: PostManager,
    isProfileTab: Bool = false,
    viewModel: ViewModel
  ) {
    self.userId = userId
    self.username = username
    self.isProfileTab = isProfileTab
    self.postManager = postManager
    _viewModel = StateObject(wrappedValue: viewModel)
  }

  var body: some View {
    mainContent
      .navigationTitle("@" + self.username)
      .sheet(isPresented: $isShowingProfileEditor) {
        ProfileEditorView(viewModel: viewModel)
          .interactiveDismissDisabled()
      }
      .toolbar {
        if !isProfileTab && !isCurrentUser {
          Menu {
            if case .loaded(let user, _) = viewModel.state {
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
      .onAppear {
        Task {
          await viewModel.loadProfile()
        }
      }
  }

  @ViewBuilder
  private var mainContent: some View {
    switch viewModel.state {
    case .idle, .loading:
      loadingPlaceholder
    case .loaded(let user, _):
      profileList(user: user)
    case .failed(let error):
      ErrorScreen(
        errorString: error.localizedDescription,
        onRetry: { await viewModel.loadProfile() }
      )
    }
  }

  private func profileList(user: UserProfile)
    -> some View
  {
    ScrollView {
      LazyVStack(spacing: 0) {
        profileHeader(user: user)

        if viewModel.posts.isEmpty {
          emptyMessage
        } else {
          ForEach(Array(viewModel.posts.enumerated()), id: \.element.id) { index, post in
            PostView(
              post: post,
              postManager: postManager,
              showAuthor: false,
              onLikeButtonTapped: { viewModel.toggleLike(on: post) },
              onPostDeleted: { viewModel.deletePost(on: post) }
            )
            .geometryGroup()
            .onAppear {
              handlePostAppear(post: post, index: index)
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
      }
    }
    .environmentObject(authManager)
    .refreshable {
      await viewModel.loadProfile()
    }
  }

  private func handlePostAppear(post: DetailedPost, index: Int) {
    if index >= viewModel.posts.count - 3 && viewModel.canLoadMorePosts {
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
      } else if isProfileTab {
        Button(action: { isShowingProfileEditor = true }) {
          Text("Edit Profile")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
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
