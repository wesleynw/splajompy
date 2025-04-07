//
//  PostTextView.swift
//  Splajompy
//
//  Created by Wesley Weisenberger on 4/6/25.
//

import Foundation
import SwiftUI

struct PostTextView: View {
  let parts: [TextPart]

  @EnvironmentObject private var feedRefreshManager: FeedRefreshManager

  init(text: String) {
    self.parts = PostTextView.parseText(text)
  }

  @ViewBuilder
  func view(for part: TextPart) -> some View {
    switch part {
    case .text(let string):
      Text(string)
    case .tag(let id, let username):
      NavigationLink(
        destination: ProfileView(
          userId: id,
          username: username,
          isOwnProfile: false
        )
        .environmentObject(feedRefreshManager)
      ) {
        Text("@\(username)")
          .foregroundColor(.blue)
          .underline()
      }
    }
  }

  var body: some View {
    HStack(spacing: 0) {
      ForEach(parts.indices, id: \.self) { index in
        view(for: parts[index])
      }
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

      let idRange = Range(match.range(at: 1), in: input)!
      let usernameRange = Range(match.range(at: 2), in: input)!

      if let id = Int(input[idRange]) {
        let username = String(input[usernameRange])
        parts.append(.tag(id: id, username: username))
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
