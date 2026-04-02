import SwiftUI

struct RelevantLikeView: View {
  let relevantLikes: [RelevantLike]

  var body: some View {
    if relevantLikes.isEmpty {
      EmptyView()
    } else {
      minimalLikesContainer
    }
  }

  private var minimalLikesContainer: some View {
    HStack(spacing: 4) {
      Text("Liked by")
        .font(.footnote)
        .foregroundStyle(.secondary)

      ForEach(Array(relevantLikes.enumerated()), id: \.element.userId) {
        index,
        like in
        HStack(spacing: 0) {
          NavigationLink(
            value: Route.profile(
              id: String(like.userId),
              username: like.username
            )
          ) {
            Text("@\(like.username)")
              .font(.footnote)
              .fontWeight(.bold)
              .foregroundStyle(.blue)
              .lineLimit(1)
          }
          .buttonStyle(.plain)

          if index < relevantLikes.count - 1 {
            Text(",")
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
        }
      }
    }
    .transition(.opacity)
  }
}

#Preview {
  RelevantLikeView(
    relevantLikes: [
      RelevantLike(username: "user1", userId: 1),
      RelevantLike(username: "user2", userId: 2),
    ],
  )
}
