import PostHog
import SwiftUI

struct OnboardingSheetViewModifier: ViewModifier {
  @AppStorage("image_layout_preference") private var imageLayoutPreference:
    ImageLayoutPreference =
      .undecided

  @AppStorage("hasCompletedPushNotificationOnboarding") private
    var hasCompletedPushNotificationOnboarding: Bool = false

  func body(content: Content) -> some View {
    content
      .sheet(
        isPresented: .constant(
          imageLayoutPreference == .undecided
            || (!hasCompletedPushNotificationOnboarding
              && PostHogSDK.shared.isFeatureEnabled(
                "push-notification-onboarding"
              ))
        )
      ) {
        NavigationStack {
          if (imageLayoutPreference == .undecided) {
            
          }
        }
      }
  }
}
