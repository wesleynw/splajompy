import PostHog
import SwiftUI

struct LikeButtonView: View {
  @Binding var isLiked: Bool
  var onLikeButtonTapped: () -> Void

  var body: some View {
    Button(action: {
      onLikeButtonTapped()
      PostHogSDK.shared.capture(isLiked ? "post_unlike" : "post_like")
    }) {
      Image(systemName: isLiked ? "heart.fill" : "heart")
        .font(.system(size: 22))
        .foregroundStyle(
          isLiked ? Color.red.gradient : Color.primary.gradient
        )
        .frame(width: 50)
        .scaleEffect(isLiked ? 1.1 : 1.0)
        .animation(
          .spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0),
          value: isLiked
        )
    }
    .sensoryFeedback(.impact, trigger: isLiked)
  }
}
