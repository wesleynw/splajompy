import SwiftUI

struct FollowersFollowingView: View {
  @StateObject private var viewModel: FollowersFollowingViewModel
  @State private var selectedTabIndex: Int

  init(userId: Int, initialTab: Int = 0) {
    let initialTabType: FollowersFollowingTab =
      initialTab == 0 ? .followers : .following
    _viewModel = StateObject(
      wrappedValue: FollowersFollowingViewModel(
        userId: userId,
        initialTab: initialTabType
      )
    )
    _selectedTabIndex = State(initialValue: initialTab)
  }

  var body: some View {
    VStack(spacing: 0) {
      switch viewModel.state {
      case .idle:
        loadingView
          .onAppear {
            Task {
              await viewModel.loadData()
            }
          }
      case .loading:
        loadingView
      case .loaded:
        loadedContent
      case .failed(let error):
        errorView(error: error)
      }
    }
    .toolbar {
      ToolbarItem(placement: .principal) {
        Picker("Tab", selection: $selectedTabIndex) {
          Text("Followers").tag(0)
          Text("Following").tag(1)
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 200)
      }
    }
    #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
    #endif
  }

  @ViewBuilder
  private var loadedContent: some View {
    TabView(selection: $selectedTabIndex) {
      userListView(
        users: viewModel.followers,
        isLoading: viewModel.isLoadingFollowers
      )
      .tag(0)

      userListView(
        users: viewModel.following,
        isLoading: viewModel.isLoadingFollowing
      )
      .tag(1)
    }
    #if os(iOS)
      .tabViewStyle(.page(indexDisplayMode: .never))
    #endif
    .onChange(of: selectedTabIndex) { _, newValue in
      viewModel.selectedTab = newValue == 0 ? .followers : .following
    }
  }

  private var loadingView: some View {
    VStack {
      Spacer()
      ProgressView()
        .scaleEffect(1.5)
      Spacer()
    }
  }

  private func errorView(error: Error) -> some View {
    VStack {
      Spacer()
      Text("Failed to load connections")
        .foregroundColor(.secondary)
      Button("Retry") {
        Task {
          await viewModel.loadData()
        }
      }
      .buttonStyle(.bordered)
      .padding()
      Spacer()
    }
  }

  private func userListView(users: [DetailedUser], isLoading: Bool) -> some View {
    Group {
      if isLoading && users.isEmpty {
        VStack {
          Spacer()
          ProgressView()
            .scaleEffect(1.5)
          Spacer()
        }
      } else if users.isEmpty {
        VStack {
          Spacer()
          Text("No users found")
            .foregroundColor(.secondary)
          Spacer()
        }
      } else {
        ScrollView {
          LazyVStack(spacing: 0) {
            ForEach(users, id: \.userId) { user in
              UserRowView(
                user: user,
                onFollowToggle: { user in
                  Task {
                    await viewModel.toggleFollow(for: user)
                  }
                }
              )
            }
          }
        }
        .refreshable {
          Task {
            await viewModel.refreshCurrentTab()
          }
        }
      }
    }
  }
}

struct UserRowView: View {
  let user: DetailedUser
  let onFollowToggle: (DetailedUser) -> Void
  @State private var isLoading = false

  var body: some View {
    HStack(spacing: 8) {
      HStack(spacing: 6) {
        if let name = user.name, !name.isEmpty {
          Text(name)
            .font(.headline)
            .lineLimit(1)
        }
        Text("@\(user.username)")
          .font(.subheadline)
          .foregroundColor(.secondary)
          .lineLimit(1)
      }

      Spacer()

      Button(action: {
        Task {
          isLoading = true
          onFollowToggle(user)
          isLoading = false
        }
      }) {
        if isLoading {
          ProgressView()
            .scaleEffect(0.8)
        } else {
          Text(user.isFollowing ? "Unfollow" : "Follow")
            .font(.caption)
            .fontWeight(.medium)
        }
      }
      .font(.caption)
      .fontWeight(.medium)
      .frame(width: 70)
      .padding(.vertical, 6)
      .background(user.isFollowing ? Color.clear : .blue)
      .foregroundColor(user.isFollowing ? .blue : .white)
      .overlay(
        RoundedRectangle(cornerRadius: 6)
          .stroke(user.isFollowing ? Color.blue : Color.clear, lineWidth: 1)
      )
      .animation(.spring(duration: 0.15, bounce: 0.3), value: user.isFollowing)
      .clipShape(RoundedRectangle(cornerRadius: 6))
      .disabled(isLoading)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
  }
}

#Preview {
  @Previewable @State var user = DetailedUser(
    userId: 1,
    email: "john@example.com",
    username: "johndoe",
    createdAt: Date(),
    name: "John Doe",
    bio: "iOS Developer",
    isFollower: true,
    isFollowing: false,
    isBlocking: false,
    mutuals: ["alice", "bob"]
  )

  return UserRowView(
    user: user,
    onFollowToggle: { _ in
      user.isFollowing.toggle()
    }
  )
}
