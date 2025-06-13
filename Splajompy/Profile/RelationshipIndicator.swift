import SwiftUI

struct RelationshipIndicator: View {
  var user: UserProfile

  var body: some View {
    switch user.relationshipType {
    case "friend":
      HStack(spacing: 6) {
        Image(systemName: "person.fill.checkmark")
          .font(.caption2)
        Text("Friend")
          .font(.caption)
          .fontWeight(.bold)
      }
      .foregroundColor(.green)
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .background(Color.green.opacity(0.1))
      .clipShape(Capsule())
      .overlay(
        Capsule()
          .strokeBorder(Color.green.opacity(0.3), lineWidth: 1)
      )
    case "mutual":
      if let mutuals = user.mutualUsernames, !mutuals.isEmpty {
        HStack(spacing: 6) {
          Image(systemName: "person.2.fill")
            .font(.caption2)
          if mutuals.count == 1 {
            Text("\(mutuals[0])")
              .font(.caption)
              .fontWeight(.bold)
              .lineLimit(1)
          } else {
            Text("\(mutuals.count) mutuals")
              .font(.caption)
              .fontWeight(.bold)
          }
        }
        .foregroundColor(mutuals.count > 1 ? .blue : .purple)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(mutuals.count > 1 ? Color.blue.opacity(0.1) : Color.purple.opacity(0.1))
        .clipShape(Capsule())
        .overlay(
          Capsule()
            .strokeBorder(mutuals.count > 1 ? Color.blue.opacity(0.3) : Color.purple.opacity(0.3), lineWidth: 1)
        )
      } else {
        HStack(spacing: 6) {
          Image(systemName: "person.2.fill")
            .font(.caption2)
          Text("Mutual")
            .font(.caption)
            .fontWeight(.bold)
        }
        .foregroundColor(.blue)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.blue.opacity(0.1))
        .clipShape(Capsule())
        .overlay(
          Capsule()
            .strokeBorder(Color.blue.opacity(0.3), lineWidth: 1)
        )
      }
    default:
      EmptyView()
    }
  }
}

#Preview {
  let currentDate = ISO8601DateFormatter().string(from: Date())
  
  VStack(spacing: 20) {
    VStack(alignment: .leading, spacing: 10) {
      Text("Friend")
        .font(.headline)
      RelationshipIndicator(user: UserProfile(
        userId: 1, 
        email: "friend@test.com", 
        username: "friend_user", 
        createdAt: currentDate, 
        name: "Friend User", 
        bio: "", 
        isFollower: false, 
        isFollowing: true, 
        isBlocking: false, 
        relationshipType: "friend", 
        mutualUsernames: nil
      ))
    }
    
    VStack(alignment: .leading, spacing: 10) {
      Text("Mutual - Single Friend")
        .font(.headline)
      RelationshipIndicator(user: UserProfile(
        userId: 2, 
        email: "mutual@test.com", 
        username: "mutual_user", 
        createdAt: currentDate, 
        name: "Mutual User", 
        bio: "", 
        isFollower: false, 
        isFollowing: true, 
        isBlocking: false, 
        relationshipType: "mutual", 
        mutualUsernames: ["alice_doe"]
      ))
    }
    
    VStack(alignment: .leading, spacing: 10) {
      Text("Mutual - Multiple Friends")
        .font(.headline)
      RelationshipIndicator(user: UserProfile(
        userId: 3, 
        email: "mutual2@test.com", 
        username: "mutual_user2", 
        createdAt: currentDate, 
        name: "Mutual User 2", 
        bio: "", 
        isFollower: false, 
        isFollowing: true, 
        isBlocking: false, 
        relationshipType: "mutual", 
        mutualUsernames: ["alice_doe", "bob_smith", "charlie_jones"]
      ))
    }
    
    VStack(alignment: .leading, spacing: 10) {
      Text("Mutual - No Usernames")
        .font(.headline)
      RelationshipIndicator(user: UserProfile(
        userId: 4, 
        email: "mutual3@test.com", 
        username: "mutual_user3", 
        createdAt: currentDate, 
        name: "Mutual User 3", 
        bio: "", 
        isFollower: false, 
        isFollowing: true, 
        isBlocking: false, 
        relationshipType: "mutual", 
        mutualUsernames: nil
      ))
    }
    
    VStack(alignment: .leading, spacing: 10) {
      Text("No Relationship")
        .font(.headline)
      RelationshipIndicator(user: UserProfile(
        userId: 5, 
        email: "stranger@test.com", 
        username: "stranger_user", 
        createdAt: currentDate, 
        name: "Stranger User", 
        bio: "", 
        isFollower: false, 
        isFollowing: false, 
        isBlocking: false, 
        relationshipType: "none", 
        mutualUsernames: nil
      ))
    }
  }
  .padding()
}
