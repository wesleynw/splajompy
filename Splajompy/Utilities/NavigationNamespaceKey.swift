import SwiftUI

private struct NavigationNamespaceKey: EnvironmentKey {
  static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
  var navigationNamespace: Namespace.ID? {
    get { self[NavigationNamespaceKey.self] }
    set { self[NavigationNamespaceKey.self] = newValue }
  }
}
