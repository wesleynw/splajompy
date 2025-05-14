import SwiftUI

struct OtherLikesView: View {
    let relevantLikes: [RelevantLike]
    let hasOtherLikes: Bool
    
    var body: some View {
        if relevantLikes.isEmpty && !hasOtherLikes {
            EmptyView()
        } else {
            HStack(spacing: 0) {
                Text("Liked by ")
              ForEach(Array(relevantLikes.enumerated()), id: \.element.userId) { index, like in
                    if index == 0 {
                        userMention(like)
                    } else if index == 1 {
                        if relevantLikes.count == 2 && hasOtherLikes {
                            Text(", ")
                            userMention(like)
                        } else {
                            Text(" and ")
                            userMention(like)
                        }
                    } else {
                        Text(", ")
                        userMention(like)
                    }
                }
                
                if hasOtherLikes {
                    if relevantLikes.isEmpty {
                        Text(" others")
                    } else if relevantLikes.count == 1 {
                        Text(" and others")
                    } else {
                        Text(", and others")
                    }
                }
            }
            .onTapGesture {
                // Prevent tap propagation
            }
        }
    }
    
    private func userMention(_ like: RelevantLike) -> some View {
        Text(
            .init(
                "**[@\(like.username)](splajompy://user?id=\(like.userId)&username=\(like.username))**"
            )
        )
    }
}

#Preview {
    OtherLikesView(
        relevantLikes: [
            RelevantLike(username: "user1", userId: 1),
            RelevantLike(username: "user2", userId: 2),
        ],
        hasOtherLikes: true
    )
}
