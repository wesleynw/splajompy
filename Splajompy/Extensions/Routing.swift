import SwiftUI

enum Route: Hashable {
  case profile(id: String, username: String)
  case post(id: Int)
  case followingList(userId: Int)
  case mutualsList(userId: Int)
  case notificationActorsList(notificationId: Int, postId: Int)
}

// TODO: remove
extension Route: CustomStringConvertible {
    var description: String {
        switch self {
        case .profile(let id, let username):
            return "profile(id: \(id), username: \(username))"
        case .post(let id):
            return "post(id: \(id))"
        case .followingList(let userId):
            return "followingList(userId: \(userId))"
        case .mutualsList(let userId):
            return "mutualsList(userId: \(userId))"
        case .notificationActorsList(let notificationId, let postId):
            return "notificationActorsList(notificationId: \(notificationId), postId: \(postId))"
        }
    }
}

enum SettingsRoute: Hashable {
  case settings
  case account
  case appearance
  case appIcon
  case secretPage
  case support
  case about
  case notifications
}

func parseDeepLink(_ url: URL) -> Route? {
  guard url.scheme == "splajompy" else { return nil }
  switch url.host {
  case "user":
    guard
      let components = URLComponents(
        url: url,
        resolvingAgainstBaseURL: false
      ),
      let idParam = components.queryItems?.first(where: { $0.name == "id" })?
        .value,
      let usernameParam = components.queryItems?.first(where: {
        $0.name == "username"
      })?.value
    else {
      return nil
    }
    return .profile(id: idParam, username: usernameParam)
  default:
    return nil
  }
}
