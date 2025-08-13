import SwiftUI

struct FollowersFollowingView: View {
  let userId: Int
  @State private var selectedTab: Int
  @State private var followers: [DetailedUser] = []
  @State private var following: [DetailedUser] = []
  @State private var isLoadingFollowers = false
  @State private var isLoadingFollowing = false
  
  private let profileService: ProfileServiceProtocol = ProfileService()
  
  init(userId: Int, initialTab: Int = 0) {
    self.userId = userId
    self._selectedTab = State(initialValue: initialTab)
  }
  
  var body: some View {
    TabView(selection: $selectedTab) {
      userListView(users: followers, isLoading: isLoadingFollowers)
        .tag(0)
      
      userListView(users: following, isLoading: isLoadingFollowing)
        .tag(1)
    }
#if os(iOS)
    .tabViewStyle(.page(indexDisplayMode: .never))
    .navigationBarTitleDisplayMode(.inline)
#endif
    .navigationTitle("Connections")
    .toolbar {
      ToolbarItem(placement: .principal) {
        Picker("Tab", selection: $selectedTab) {
          Text("Followers").tag(0)
          Text("Following").tag(1)
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 200)
      }
    }
    .onAppear {
      Task {
        await loadFollowers()
        await loadFollowing()
      }
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
              UserRowView(user: user, onFollowToggle: { user in
                Task {
                  await toggleFollow(for: user)
                }
              })
            }
          }
        }
        .refreshable {
          Task {
            if selectedTab == 0 {
              await loadFollowers()
            } else {
              await loadFollowing()
            }
          }
        }
      }
    }
  }
  
  private func loadFollowers() async {
    isLoadingFollowers = true
    let result = await profileService.getFollowers(userId: userId, offset: 0, limit: 50)
    switch result {
    case .success(let users):
      followers = users
    case .error(let error):
      print("Failed to load followers: \(error)")
    }
    isLoadingFollowers = false
  }
  
  private func loadFollowing() async {
    isLoadingFollowing = true
    let result = await profileService.getFollowing(userId: userId, offset: 0, limit: 50)
    switch result {
    case .success(let users):
      following = users
    case .error(let error):
      print("Failed to load following: \(error)")
    }
    isLoadingFollowing = false
  }
  
  private func toggleFollow(for user: DetailedUser) async {
    let isCurrentlyFollowing = user.isFollowing
    let newFollowingState = !isCurrentlyFollowing
    
    // Optimistic update
    updateUserFollowState(userId: user.userId, isFollowing: newFollowingState)
    
    let result = await profileService.toggleFollowing(
      userId: user.userId, 
      isFollowing: isCurrentlyFollowing
    )
    
    switch result {
    case .success:
      // Optimistic update was correct, no need to change anything
      break
    case .error(let error):
      // Revert the optimistic update on error
      updateUserFollowState(userId: user.userId, isFollowing: isCurrentlyFollowing)
      print("Failed to toggle follow: \(error)")
    }
  }
  
  private func updateUserFollowState(userId: Int, isFollowing: Bool) {
    // Update in followers array
    if let index = followers.firstIndex(where: { $0.userId == userId }) {
      followers[index].isFollowing = isFollowing
    }
    
    // Update in following array
    if let index = following.firstIndex(where: { $0.userId == userId }) {
      following[index].isFollowing = isFollowing
    }
  }
}

struct UserRowView: View {
  let user: DetailedUser
  let onFollowToggle: (DetailedUser) -> Void
  @State private var isLoading = false
  
  var body: some View {
    HStack(spacing: 8) {
      // Name and username horizontally
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
      
      // Follow/Unfollow button
      Button(action: {
        isLoading = true
        onFollowToggle(user)
        isLoading = false
      }) {
        if isLoading {
          ProgressView()
            .scaleEffect(0.8)
        } else {
          Text(user.isFollowing ? "Unfollow" : "Follow")
        }
      }
#if os(iOS)
      .buttonStyle(user.isFollowing ? .bordered : .borderedProminent)
#else
      .buttonStyle(.bordered)
#endif
      .font(.caption)
      .disabled(isLoading)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
  }
}