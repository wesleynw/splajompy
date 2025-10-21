import SwiftUI

extension View {
  @ViewBuilder
  func modify(@ViewBuilder _ fn: (Self) -> some View) -> some View {
    fn(self)
  }
}
