import SwiftUI

private func miniContentView(text: String, font: Font, lineLimit: Int) -> some View {
  VStack(alignment: .leading, spacing: 4) {
    Text(text.replacingOccurrences(of: "\n", with: " "))
      .font(font)
      .lineLimit(lineLimit)
      .foregroundColor(.secondary)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
  .padding(8)
  .background(Color.gray.opacity(0.1))
  .cornerRadius(8)
  .frame(maxWidth: .infinity)
}

struct MiniNotificationView: View {
  let text: String

  var body: some View {
    miniContentView(text: text, font: .callout, lineLimit: 3)
  }
}

struct MiniPostView: View {
  let post: Post

  var body: some View {
    Group {
      if let postText = post.text?.replacingOccurrences(of: "\n", with: " "),
        !postText.isEmpty
      {
        miniContentView(text: postText, font: .callout, lineLimit: 3)
      }
    }
  }
}

struct MiniCommentView: View {
  let comment: Comment

  var body: some View {
    miniContentView(text: comment.text, font: .caption2, lineLimit: 2)
  }
}
