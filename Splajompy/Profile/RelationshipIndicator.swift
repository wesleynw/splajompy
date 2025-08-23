import SwiftUI

struct RelationshipIndicator: View {
  let user: UserProfile

  var body: some View {
    VStack(spacing: 4) {
      if hasMutuals {
        mutualsRow()
      } else {
        noConnectionRow()
      }
    }
    .padding(12)
    .background(Color.gray.opacity(0.1))
    .cornerRadius(12)
  }

  @ViewBuilder
  private func mutualsRow() -> some View {
    HStack(spacing: 0) {
      Image(systemName: "person.3.fill")
        .font(.system(size: 16))
        .foregroundColor(.purple)
        .frame(width: 24, alignment: .center)

      VStack(alignment: .leading, spacing: 4) {
        Text(mutualFriendsTitle)
          .font(.subheadline)
          .fontWeight(.medium)
          .foregroundColor(.primary)
          .lineLimit(2)

        Text(formatMutualFriends(user.mutuals))
          .font(.caption)
          .foregroundColor(.secondary)
      }
      .padding(.leading, 12)

      Spacer()
    }
  }

  @ViewBuilder
  private func noConnectionRow() -> some View {
    HStack(spacing: 0) {
      Image(systemName: "person.fill")
        .font(.system(size: 16))
        .foregroundColor(.blue)
        .frame(width: 24, alignment: .center)

      VStack(alignment: .leading, spacing: 4) {
        Text("No connection")
          .font(.subheadline)
          .fontWeight(.medium)
          .foregroundColor(.primary)
          .lineLimit(2)
      }
      .padding(.leading, 12)

      Spacer()
    }
  }

  private var mutualFriendsTitle: String {
    let count = user.mutuals.count
    return count == 1 ? "1 mutual" : "\(count) mutuals"
  }

  private var isFriend: Bool {
    user.isFollowing && user.isFollower
  }

  private var hasMutuals: Bool {
    !user.mutuals.isEmpty
  }

  private func formatMutualFriends(_ mutuals: [String]) -> String {
    if mutuals.count == 1 {
      return "@\(mutuals[0])"
    } else if mutuals.count == 2 {
      return "@\(mutuals[0]) and @\(mutuals[1])"
    } else if mutuals.count == 3 {
      return "@\(mutuals[0]), @\(mutuals[1]) and @\(mutuals[2])"
    } else {
      return "@\(mutuals[0]), @\(mutuals[1]) and \(mutuals.count - 2) others"
    }
  }
}

#Preview {
  VStack(spacing: 16) {
    RelationshipIndicator(
      user: UserProfile(
        userId: 1,
        email: "friend@example.com",
        username: "friend_user",
        createdAt: "2024-01-01T00:00:00.000Z",
        name: "Friend User",
        bio: "This is a friend",
        isFollower: true,
        isFollowing: true,
        isBlocking: false,
        mutuals: []
      )
    )

    RelationshipIndicator(
      user: UserProfile(
        userId: 4,
        email: "friend_with_mutuals@example.com",
        username: "friend_with_mutuals",
        createdAt: "2024-01-01T00:00:00.000Z",
        name: "Friend With Mutuals",
        bio: "Friend who also has mutuals",
        isFollower: true,
        isFollowing: true,
        isBlocking: false,
        mutuals: ["alice", "bob", "charlie"]
      )
    )

    RelationshipIndicator(
      user: UserProfile(
        userId: 2,
        email: "mutual@example.com",
        username: "mutual_user",
        createdAt: "2024-01-01T00:00:00.000Z",
        name: "Mutual User",
        bio: "Has mutual friends",
        isFollower: false,
        isFollowing: false,
        isBlocking: false,
        mutuals: ["alice", "bob"]
      )
    )

    RelationshipIndicator(
      user: UserProfile(
        userId: 3,
        email: "none@example.com",
        username: "no_connection",
        createdAt: "2024-01-01T00:00:00.000Z",
        name: "No Connection",
        bio: "No relationship",
        isFollower: false,
        isFollowing: false,
        isBlocking: false,
        mutuals: []
      )
    )
  }
  .padding()
}
