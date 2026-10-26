import SwiftUI

struct CommentReplyGesture: Gesture {
  var onTrigger: () -> Void
  let replyThreshold: CGFloat = 60.0

  @Binding var replyGestureOffset: CGFloat

  var body: some Gesture {
    DragGesture(minimumDistance: 20, coordinateSpace: .global)
      .onChanged { value in
        let x = max(0, value.translation.width)
        let resisted = 120 * (1 - exp(-x / 120))
        replyGestureOffset = resisted
      }
      .onEnded { value in
        replyGestureOffset = .zero

        if value.translation.width > replyThreshold {
          onTrigger()
        }
      }
  }
}
