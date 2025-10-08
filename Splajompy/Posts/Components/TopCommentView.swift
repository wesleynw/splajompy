import SwiftUI

struct TopCommentView: View {
  let comment: DetailedComment
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 4) {
          Text("@\(comment.user.username)")
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.blue)
          if let displayName = comment.user.name, !displayName.isEmpty {
            Text(displayName)
              .font(.caption)
              .fontWeight(.medium)
              .foregroundColor(.secondary)
          }
        }

        Text(comment.richContent)
          .font(.caption)
          .foregroundColor(.primary)
          .lineLimit(2)
          .truncationMode(.tail)
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 6)
      .background(
        RoundedRectangle(cornerRadius: 8)
          .fill(Color.gray.opacity(0.1))
      )
    }
    .buttonStyle(.plain)
  }
}

#Preview {
  let dateFormatter = ISO8601DateFormatter()
  dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

  let user = User(
    userId: 1,
    email: "test@example.com",
    username: "testuser",
    createdAt: Date(),
    name: "Test User"
  )

  let comment = DetailedComment(
    commentId: 1,
    postId: 1,
    userId: 1,
    text:
      "This is a sample comment that might be quite long and will need to be truncated to fit in the preview",
    createdAt: "2025-04-01T12:30:45.123Z",
    user: user,
    facets: nil,
    isLiked: true
  )

  return TopCommentView(comment: comment, onTap: {})
    .padding()
}
