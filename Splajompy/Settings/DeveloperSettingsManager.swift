import Foundation

struct DeveloperSettingsManager: Equatable, Sendable {
  enum Setting: String, Sendable {
    case apiServerURL = "API Server URL"
  }

  static let settingsRequiringSignOut: Set<Setting> = [.apiServerURL]

  var apiServerURL: String

  static let defaults: DeveloperSettingsManager = {
    let settings = DeveloperSettingsManager(apiServerURL: APIService.defaultBaseUrl)
    return settings.validated ?? settings
  }()

  static var current: DeveloperSettingsManager {
    DeveloperSettingsManager(apiServerURL: APIService.baseUrl)
  }

  var validated: DeveloperSettingsManager? {
    guard
      var components = URLComponents(
        string: apiServerURL.trimmingCharacters(in: .whitespacesAndNewlines)),
      let scheme = components.scheme?.lowercased(), ["http", "https"].contains(scheme),
      let host = components.host, !host.isEmpty,
      components.user == nil, components.password == nil,
      components.query == nil, components.fragment == nil,
      components.path.isEmpty || components.path == "/",
      components.port.map({ (1...65535).contains($0) }) ?? true
    else { return nil }
    components.path = ""
    guard let url = components.url else { return nil }
    var settings = self
    settings.apiServerURL = url.absoluteString
    return settings
  }

  func changedSettings(from original: DeveloperSettingsManager) -> [Setting] {
    var changes: [Setting] = []
    if validated?.apiServerURL != original.validated?.apiServerURL {
      changes.append(.apiServerURL)
    }
    return changes
  }
}
