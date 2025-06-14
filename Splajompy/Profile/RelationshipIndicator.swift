import SwiftUI

struct RelationshipIndicator: View {
  let user: UserProfile

  var body: some View {
    VStack(spacing: 0) {
      relationshipRow()
    }
    .padding(12)
    .background(Color.gray.opacity(0.1))
    .cornerRadius(12)
  }

  @ViewBuilder
  private func relationshipRow() -> some View {
    HStack(spacing: 0) {
      relationshipIcon
        .font(.system(size: 16))
        .foregroundColor(relationshipColor)
        .frame(width: 24, alignment: .center)

      VStack(alignment: .leading, spacing: 4) {
        Text(relationshipTitle)
          .font(.subheadline)
          .fontWeight(.medium)
          .foregroundColor(.primary)
          .lineLimit(2)

        if hasMutuals {
          Text(formatMutualFriends(user.mutuals))
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
      .padding(.leading, 12)

      Spacer()
    }
  }

  private var relationshipIcon: Image {
    if isFriend {
      return Image(systemName: "person.fill.checkmark")
    } else if hasMutuals {
      return Image(systemName: "person.3.fill")
    } else {
      return Image(systemName: "person.fill")
    }
  }

  private var relationshipColor: Color {
    if isFriend {
      return .green
    } else if hasMutuals {
      return .purple
    } else {
      return .blue
    }
  }

  private var relationshipTitle: String {
    if isFriend {
      return "Friend"
    } else if hasMutuals {
      let count = user.mutuals.count
      return count == 1 ? "1 mutual friend" : "\(count) mutual friends"
    } else {
      return "No connection"
    }
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
