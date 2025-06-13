import SwiftUI

struct OnboardingView: View {
  let onComplete: () -> Void

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 32) {
          Text(
            "With more people joining Splajompy, it's important that it stays safe and familiar. I build this app originally because I was tired of social-media, and I don't want this to be the same."
          ).fontWeight(.semibold).multilineTextAlignment(.center)
          Text(
            "So, from now on the Splajompy home page will no longer show posts from all Splajompians, rather only posts from friends and mutual friends."
          ).multilineTextAlignment(.center).fontWeight(.semibold)

          Text(
            "This is meant to keep us all connected with our friends, allow for us to discover their friends, and have a safe place for just for us in this noisy world."
          )
          .multilineTextAlignment(.center)
          .fontWeight(.semibold)

          HStack {
            Spacer()

            RelationshipIndicator(
              user: UserProfile(
                userId: 1,
                email: "friend@example.com",
                username: "friend_user",
                createdAt: ISO8601DateFormatter().string(from: Date()),
                name: "Friend User",
                bio: "",
                isFollower: false,
                isFollowing: true,
                isBlocking: false,
                relationshipType: "friend",
                mutualUsernames: nil
              )
            )

            RelationshipIndicator(
              user: UserProfile(
                userId: 2,
                email: "mutual@example.com",
                username: "mutual_user",
                createdAt: ISO8601DateFormatter().string(from: Date()),
                name: "Mutual User",
                bio: "",
                isFollower: false,
                isFollowing: false,
                isBlocking: false,
                relationshipType: "mutual",
                mutualUsernames: ["wesley"]
              )
            )

            RelationshipIndicator(
              user: UserProfile(
                userId: 3,
                email: "mutual2@example.com",
                username: "mutual_user2",
                createdAt: ISO8601DateFormatter().string(from: Date()),
                name: "Mutual User 2",
                bio: "",
                isFollower: false,
                isFollowing: false,
                isBlocking: false,
                relationshipType: "mutual",
                mutualUsernames: ["bob", "charlie", "diana"]
              )
            )
            Spacer()
          }
        }

        Text(
          "The profiles of other Splajompians will be annotated on whether they're a friend, which mutual you know of theirs, or how many mutuals you share."
        ).padding().multilineTextAlignment(.center).fontWeight(.semibold)

        Button("Get Started") {
          onComplete()
        }
        .font(.headline)
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.blue)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.top, 16)
      }
      .padding(32)
      .navigationTitle("What's New")
    }
  }
}

#Preview {
  OnboardingView {
    print("done")
  }
}
