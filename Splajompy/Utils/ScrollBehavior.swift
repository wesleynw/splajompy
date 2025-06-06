import Foundation

enum ScrollBehavior: String, CaseIterable {
  case defaultScroll = "default"
  case reels = "reels"
  
  var displayName: String {
    switch self {
    case .defaultScroll:
      return "Default"
    case .reels:
      return "Mindless Mode"
    }
  }
} 