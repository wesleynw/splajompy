import SwiftUI

enum Route: Hashable {
  case profile(id: String, username: String)
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
