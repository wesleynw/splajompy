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
        Image(systemName: "heart.fill")
          .font(.system(size: 16))
          .foregroundColor(.red)

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
            Image(systemName: "person.2.fill")
              .font(.system(size: 10))
              .foregroundColor(.gray)
          }
          .padding(.horizontal, 6)
          .padding(.vertical, 4)
          .background(
            RoundedRectangle(cornerRadius: 12)
              .fill(Color.gray.opacity(0.15))
          )
        }
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(
        RoundedRectangle(cornerRadius: 16)
          .fill(Color.gray.opacity(0.1))
      )

      Spacer()
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
