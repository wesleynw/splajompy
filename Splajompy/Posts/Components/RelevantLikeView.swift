import SwiftUI

struct RelevantLikeView: View {
  let relevantLikes: [RelevantLike]
  let hasOtherLikes: Bool

  var body: some View {
    if relevantLikes.isEmpty && !hasOtherLikes {
      EmptyView()
    } else {
      likesContainer
    }
  }

  private var likesContainer: some View {
    HStack(spacing: 8) {
      HStack(spacing: 6) {
        Text("Liked by")
          .font(.caption)
          .fontWeight(.medium)
          .foregroundColor(.secondary)

        ForEach(relevantLikes, id: \.userId) { like in
          NavigationLink(
            value: Route.profile(
              id: String(like.userId),
              username: like.username
            )
          ) {
            Text("@\(like.username)")
              .font(.caption)
              .fontWeight(.medium)
              .foregroundColor(.blue)
              .lineLimit(1)
              .truncationMode(.tail)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(
                RoundedRectangle(cornerRadius: 12)
                  .fill(Color.gray.opacity(0.2))
              )
          }
          .buttonStyle(.plain)
        }

        if hasOtherLikes {
          HStack(spacing: 2) {
            Image(systemName: "plus")
              .font(.caption)
              .foregroundColor(.gray)
            Image(systemName: "person.2.fill")
              .font(.caption)
              .foregroundColor(.gray)
          }
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(
            RoundedRectangle(cornerRadius: 12)
              .fill(Color.gray.opacity(0.15))
          )
        }
      }
      .padding(.horizontal, 5)
      .padding(.vertical, 3)
      .transition(.opacity)
    }
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
