import SwiftUI

struct RelationshipIndicator: View {
  let user: UserProfile

  var body: some View {
    if !user.mutuals.isEmpty {
      NavigationLink(value: Route.mutualsList(userId: user.userId)) {
        HStack {
          Image(systemName: "person.3.fill")
            .font(.system(size: 16))
            .foregroundColor(.purple)

          VStack(alignment: .leading, spacing: 4) {
            Text(mutualFriendsTitle)
              .font(.subheadline)
              .fontWeight(.medium)
              .foregroundColor(.primary)
              .lineLimit(2)

            Text(formatMutualFriends(user.mutuals))
              .font(.footnote)
              .foregroundColor(.secondary)
          }

          Spacer()

          Image(systemName: "chevron.right")
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.secondary.opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .modify {
          if #available(iOS 26, *) {
            $0.background(.quinary, in: .containerRelative)
          } else {
            $0.background(.quinary, in: .rect(cornerRadius: 12))
          }
        }
      }
      .buttonStyle(.plain)
    }
  }

  private var mutualFriendsTitle: String {
    let count = user.mutuals.count
    return count == 1 ? "1 mutual" : "\(count) mutuals"
  }

  private func formatMutualFriends(_ mutuals: [String]) -> String {
    if mutuals.count == 1 {
      return "@\(mutuals[0])"
    } else if mutuals.count == 2 {
      return "@\(mutuals[0]) and @\(mutuals[1])"
    } else if mutuals.count == 3 {
      return "@\(mutuals[0]), @\(mutuals[1]), and @\(mutuals[2])"
    } else {
      return "@\(mutuals[0]), @\(mutuals[1]) and \(mutuals.count - 2) others"
    }
  }
}

#Preview {
  NavigationStack {
    VStack(spacing: 16) {
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
          mutuals: ["alice", "bob", "charlie", "dan", "ethan"]
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
          mutuals: ["alice"]
        )
      )
    }
    .padding()
  }
}
