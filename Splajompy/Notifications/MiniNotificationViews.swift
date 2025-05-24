import SwiftUI

struct MiniNotificationView: View {
  let text: String

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      ContentTextView(text: text.replacingOccurrences(of: "\n", with: " "), facets: [])
        .font(.callout)
        .lineLimit(3)
        .foregroundColor(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(8)
    .background(Color.gray.opacity(0.1))
    .cornerRadius(8)
    .frame(maxWidth: .infinity)
  }
}

struct MiniPostView: View {
  let post: Post

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      if let postText = post.text?.replacingOccurrences(of: "\n", with: " "),
        !postText.isEmpty
      {
        Text(postText)
          .font(.callout)
          .lineLimit(3)
          .foregroundColor(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .padding(8)
    .background(Color.gray.opacity(0.1))
    .cornerRadius(8)
    .frame(maxWidth: .infinity)
  }
}

struct MiniCommentView: View {
  let comment: Comment

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(comment.text)
        .font(.caption2)
        .lineLimit(2)
        .foregroundColor(.secondary)
    }
    .padding(8)
    .background(Color.gray.opacity(0.1))
    .cornerRadius(8)
  }
}
