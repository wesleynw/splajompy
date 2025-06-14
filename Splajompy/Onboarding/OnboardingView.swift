import SwiftUI

struct OnboardingView: View {
  let onComplete: () -> Void

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 32) {
          VStack(spacing: 16) {
            Text(
              "From now on, the posts you will see in your feed will be from"
            ) + Text(" friends ").foregroundStyle(.green) + Text("and")
              + Text(" mutuals").foregroundStyle(.purple) + Text(".")

            Text(
              "If you're curious why you're seeing someone's posts, you can see why they're showing up for you in their profile."
            )
          }
          .multilineTextAlignment(.center)

          VStack(spacing: 12) {
            RelationshipIndicator(
              user: UserProfile(
                userId: 1,
                email: "friend@example.com",
                username: "friend_example",
                createdAt: "2024-01-01T00:00:00.000Z",
                name: "Friend Example",
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
                username: "mutual_example",
                createdAt: "2024-01-01T00:00:00.000Z",
                name: "Mutual Example",
                bio: "Has mutual friends",
                isFollower: false,
                isFollowing: false,
                isBlocking: false,
                mutuals: ["alice", "bob"]
              )
            )
          }
        }
      }
      .padding(32)
      .navigationTitle("What's New")

      VStack {
        Spacer()

        Button(action: onComplete) {
          Text("Get Started")
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .buttonStyle(.borderedProminent)
        .padding()
      }

    }
  }
}

#Preview {
  OnboardingView {
    print("done")
  }
}
