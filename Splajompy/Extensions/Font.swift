import SwiftUI

enum SFontWeight: String {
  case prominent = "Splajompy-Regular"
  case body = "SplajompyBody-Regular"
  case bold = "SplajompyBody-Bold"
}

enum STypography {
  static let sizeMappings: [Font.TextStyle: CGFloat] = [
    .title: 28,
    .title2: 24,
    .title3: 22,
    .headline: 21,
    .body: 20,
    .callout: 17,
    .footnote: 10,
  ]
}

struct SFont {
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

  static func sized(to size: Font.TextStyle, weight: SFontWeight)
    -> Font
  {
    return Font.custom(
      weight.rawValue,
      size: STypography.sizeMappings[size] ?? 20.0,
      relativeTo: size
    )
  }
}
