import SwiftUI

struct CommentReplyGesture: Gesture {
  var onTrigger: () -> Void
  let replyThreshold: CGFloat = 60.0

  @Binding var replyGestureOffset: CGFloat

  var body: some Gesture {
    DragGesture(minimumDistance: 30)
      .onChanged { value in
        let isHorizontal = abs(value.translation.width) > abs(value.translation.height)

        if isHorizontal {
          let x = max(0, value.translation.width)
          let resisted = 120 * (1 - exp(-x / 120))
          replyGestureOffset = resisted
        }
      }
      .onEnded { value in
        replyGestureOffset = .zero

        let isHorizontal = abs(value.translation.width) > abs(value.translation.height)
        if isHorizontal && value.translation.width > replyThreshold {
          onTrigger()
        }
      }
  }
}
