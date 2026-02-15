import SwiftUI

struct RelevantLikeView: View {
  let relevantLikes: [RelevantLike]
  let hasOtherLikes: Bool

  var body: some View {
    if relevantLikes.isEmpty && !hasOtherLikes {
      EmptyView()
    } else if relevantLikes.isEmpty && hasOtherLikes {
      othersOnlyView
    } else {
      minimalLikesContainer
    }
  }

  private var minimalLikesContainer: some View {
    HStack(spacing: 4) {
      Text("Liked by")
        .font(.footnote)
        .foregroundColor(.secondary)

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
              .foregroundColor(.blue)
              .lineLimit(1)
          }
          .buttonStyle(.plain)

          if index < relevantLikes.count - 1 || hasOtherLikes {
            Text(",")
              .font(.footnote)
              .foregroundColor(.secondary)
          }
        }
      }

      if hasOtherLikes {
        Text("and others")
          .font(.footnote)
          .foregroundColor(.secondary)
      }
    }
    .transition(.opacity)
  }

  private var othersOnlyView: some View {
    HStack(spacing: 4) {
      Text("Liked by others")
        .font(.footnote)
        .foregroundColor(.secondary)
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
    hasOtherLikes: true
  )
}
