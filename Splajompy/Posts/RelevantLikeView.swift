import SwiftUI

struct RelevantLikeView: View {
  let relevantLikes: [RelevantLike]
  let hasOtherLikes: Bool

  var body: some View {
    if relevantLikes.isEmpty && !hasOtherLikes {
      EmptyView()
    } else {
      likesText
        .font(.footnote)
        .fontWeight(.semibold)
    }
  }

  private var likesText: some View {
    Text(.init(buildLikesString()))
  }

  private func buildLikesString() -> String {
    let prefix = "Liked by "

    if relevantLikes.isEmpty {
      return prefix + "others"
    }

    var components = [String]()

    for (index, like) in relevantLikes.enumerated() {
      let username =
        "**[@\(like.username)](splajompy://user?id=\(like.userId)&username=\(like.username))**"

      if index == 0 {
        components.append(username)
      } else if index == 1 && relevantLikes.count == 2 && hasOtherLikes {
        components.append(", " + username)
      } else if index == 1 {
        components.append(" and " + username)
      } else {
        components.append(", " + username)
      }
    }

    let result = prefix + components.joined()

    if hasOtherLikes {
      return result
        + (relevantLikes.count == 1 ? " and others" : ", and others")
    }

    return result
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
