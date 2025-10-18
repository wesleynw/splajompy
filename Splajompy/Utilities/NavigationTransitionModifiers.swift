import SwiftUI

struct TransitionSourceModifier: ViewModifier {
  let id: String
  let namespace: Namespace.ID

  func body(content: Content) -> some View {
    #if os(iOS)
      if #available(iOS 18.0, *) {
        content.matchedTransitionSource(id: id, in: namespace)
      } else {
        content
      }
    #else
      content
    #endif
  }
}

struct NavigationTransitionModifier: ViewModifier {
  let sourceID: String
  let namespace: Namespace.ID

  func body(content: Content) -> some View {
    #if os(iOS)
      if #available(iOS 18.0, *) {
        content.navigationTransition(.zoom(sourceID: sourceID, in: namespace))
      } else {
        content
      }
    #else
      content
    #endif
  }
}

struct OptionalTransitionSourceModifier: ViewModifier {
  let id: String
  let namespace: Namespace.ID?

  func body(content: Content) -> some View {
    if let namespace = namespace {
      content.modifier(TransitionSourceModifier(id: id, namespace: namespace))
    } else {
      content
    }
  }
}

struct OptionalNavigationTransitionModifier: ViewModifier {
  let sourceID: String
  let namespace: Namespace.ID?

  func body(content: Content) -> some View {
    if let namespace = namespace {
      content.modifier(NavigationTransitionModifier(sourceID: sourceID, namespace: namespace))
    } else {
      content
    }
  }
}
