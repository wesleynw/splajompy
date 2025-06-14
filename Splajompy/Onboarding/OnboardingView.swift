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
              "If you're curious why you're seeing someone's posts, you can why they're showing up for you in their profile."
            )
          }
          .multilineTextAlignment(.center)

          VStack(spacing: 12) {
            RelationshipIndicator(
              relationshipType: "friend",
              mutualUsernames: nil,
              isFollower: false
            )

            RelationshipIndicator(
              relationshipType: "mutual",
              mutualUsernames: ["alice", "bob"],
              isFollower: false
            )

            RelationshipIndicator(
              relationshipType: "none",
              mutualUsernames: nil,
              isFollower: true
            )
          }
        }
      }
      .padding(32)
      .navigationTitle("What's New")

      HStack {
        Button(action: onComplete) {
          Text("Get Started")
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .buttonStyle(.borderedProminent)
      }
      .padding()

    }
  }
}

#Preview {
  OnboardingView {
    print("done")
  }
}
