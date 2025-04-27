import Foundation
import SwiftUI

struct ContentTextView: View {
  let parts: [TextPart]
  @State private var selectedUserId: Int?
  @State private var selectedUsername: String?
  @EnvironmentObject private var feedRefreshManager: FeedRefreshManager

  init(text: String) {
    self.parts = ContentTextView.parseText(text)
  }

  var body: some View {
    HStack(spacing: 0) {
      ForEach(parts.indices, id: \.self) { index in
        viewForPart(parts[index])
      }
    }
    .lineLimit(nil)
  }

  @ViewBuilder
  private func viewForPart(_ part: TextPart) -> some View {
    switch part {
    case .text(let string):
      Text(string)
    case .tag(let id, let username):
      NavigationLink {
        ProfileView(userId: id, username: username)
      } label: {
        Text("@\(username)")
          .foregroundColor(.blue)
      }
      .buttonStyle(PlainButtonStyle())
    }
  }

  static func parseText(_ input: String) -> [TextPart] {
    let regex = try! NSRegularExpression(pattern: #"\{tag:(\d+):([^\}]+)\}"#)
    var parts: [TextPart] = []
    var currentIndex = input.startIndex

    for match in regex.matches(
      in: input,
      range: NSRange(input.startIndex..., in: input)
    ) {
      let matchRange = Range(match.range, in: input)!

      if currentIndex < matchRange.lowerBound {
        parts.append(.text(String(input[currentIndex..<matchRange.lowerBound])))
      }

      if let idRange = Range(match.range(at: 1), in: input),
        let usernameRange = Range(match.range(at: 2), in: input),
        let id = Int(input[idRange])
      {
        parts.append(.tag(id: id, username: String(input[usernameRange])))
      }

      currentIndex = matchRange.upperBound
    }

    if currentIndex < input.endIndex {
      parts.append(.text(String(input[currentIndex...])))
    }

    return parts
  }
}

enum TextPart {
  case text(String)
  case tag(id: Int, username: String)
}
