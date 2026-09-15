import SwiftUI

struct SJFont {
  #if os(iOS)
    static let title = Font.custom(
      "Splajompy-Regular",
      size: 26,
      relativeTo: .title
    )
  #else
    static let title = Font.custom(
      "Splajompy-Regular",
      size: 20,
      relativeTo: .title
    )
  #endif
  static let title2 = Font.custom(
    "Splajompy-Regular",
    size: 23,
    relativeTo: .title2
  )
  static let title3 = Font.custom(
    "Splajompy-Regular",
    size: 20,
    relativeTo: .title3
  )
  static let heading = Font.custom(
    "Splajompy-Regular",
    size: 18,
    relativeTo: .headline
  )
  static let callout = Font.custom(
    "Splajompy-Regular",
    size: 17,
    relativeTo: .headline
  )
  static let body = Font.custom(
    "Splajompy-Regular",
    size: 15,
    relativeTo: .body
  )
  static let footnote = Font.custom(
    "Splajompy-Regular",
    size: 10,
    relativeTo: .footnote
  )
}
