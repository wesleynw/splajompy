import SwiftUI

struct RelationshipIndicator: View {
  let relationshipType: String
  let mutualUsernames: [String]?
  let isFollower: Bool

  private var hasRelationship: Bool {
    relationshipType != "none" && !relationshipType.isEmpty
  }

  var body: some View {
    if hasRelationship || isFollower {
      VStack(spacing: 8) {
        if hasRelationship {
          relationshipRow()
        }

        if isFollower {
          followsYouRow()
        }
      }
      .padding(12)
      .background(Color.gray.opacity(0.3).gradient)
      .cornerRadius(8)
    }
  }

  @ViewBuilder
  private func relationshipRow() -> some View {
    HStack(spacing: 0) {
      relationshipIcon(for: relationshipType)
        .font(.system(size: 16))
        .foregroundColor(relationshipColor(for: relationshipType))
        .frame(width: 24, alignment: .center)

      VStack(alignment: .leading, spacing: 4) {
        Text(relationshipTitle(for: relationshipType))
          .font(.subheadline)
          .fontWeight(.medium)
          .foregroundColor(.primary)
          .lineLimit(2)

        if let mutuals = mutualUsernames, !mutuals.isEmpty,
          relationshipType == "mutual"
        {
          Text(formatMutualFriends(mutuals))
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
      }
      .padding(.leading, 12)

      Spacer()
    }
  }

  @ViewBuilder
  private func followsYouRow() -> some View {
    HStack(spacing: 0) {
      Image(systemName: "person.fill.badge.plus")
        .font(.system(size: 16))
        .foregroundColor(.blue)
        .frame(width: 24, alignment: .center)

      Text("Follows you")
        .font(.subheadline)
        .fontWeight(.medium)
        .padding(.leading, 12)

      Spacer()
    }
  }

  private func relationshipIcon(for type: String) -> Image {
    switch type {
    case "friend":
      return Image(systemName: "person.fill.checkmark")
    case "mutual":
      return Image(systemName: "person.3.fill")
    default:
      return Image(systemName: "person.fill")
    }
  }

  private func relationshipColor(for type: String) -> Color {
    switch type {
    case "friend":
      return .green
    case "mutual":
      return .purple
    default:
      return .blue
    }
  }

  private func relationshipTitle(for type: String) -> String {
    switch type {
    case "friend":
      return "Friend"
    case "mutual":
      if let mutuals = mutualUsernames, !mutuals.isEmpty {
        return mutuals.count == 1 ? "1 mutual" : "\(mutuals.count) mutuals"
      } else {
        return "Mutual"
      }
    default:
      return "Mutual"
    }
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
      relationshipType: "friend",
      mutualUsernames: nil,
      isFollower: false
    )

    RelationshipIndicator(
      relationshipType: "mutual",
      mutualUsernames: ["alice", "bob"],
      isFollower: true
    )

    RelationshipIndicator(
      relationshipType: "none",
      mutualUsernames: nil,
      isFollower: true
    )
  }
  .padding()
}
