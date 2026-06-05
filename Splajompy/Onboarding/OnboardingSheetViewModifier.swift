import PostHog
import SwiftUI

struct OnboardingSheetViewModifier: ViewModifier {
  @AppStorage("image_layout_preference") private var imageLayoutPreference: ImageLayoutPreference =
    .undecided
  @State private var tempImageLayoutPreference: ImageLayoutPreference =
    .undecided

  @AppStorage("hasCompletedPushNotificationOnboarding") private
    var hasCompletedPushNotificationOnboarding: Bool = false

  @AppStorage("push_notifications_enabled") private
    var isPushNotificationsAlreadyEnabled: Bool = false

  @State private var isNavigationToPushNotificationOnboarding: Bool = false

  func body(content: Content) -> some View {
    content
      .sheet(
        isPresented: .constant(
          imageLayoutPreference == .undecided
            || (!hasCompletedPushNotificationOnboarding
              && !isPushNotificationsAlreadyEnabled
              && PostHogSDK.shared.isFeatureEnabled(
                "push-notifications-onboarding"
              ))
        )
      ) {
        Group {
          NavigationStack {
            if imageLayoutPreference == .undecided {
              ImageLayoutOnboardingView(
                onComplete: {
                  if !hasCompletedPushNotificationOnboarding
                    && !isPushNotificationsAlreadyEnabled
                    && PostHogSDK.shared.isFeatureEnabled(
                      "push-notifications-onboarding"
                    )
                  {
                    isNavigationToPushNotificationOnboarding = true
                  } else {
                    imageLayoutPreference = tempImageLayoutPreference
                  }
                },
                preference: $tempImageLayoutPreference
              )
              .navigationDestination(
                isPresented: $isNavigationToPushNotificationOnboarding
              ) {
                PushNotificationsOnboardingView(
                  onComplete: {
                    imageLayoutPreference = tempImageLayoutPreference
                    hasCompletedPushNotificationOnboarding = true
                  }
                )
                .toolbar(.hidden, for: .navigationBar)
              }
            } else {
              PushNotificationsOnboardingView(
                onComplete: {
                  hasCompletedPushNotificationOnboarding = true
                }
              )
              .toolbar(.hidden, for: .navigationBar)
            }
          }
        }
        .interactiveDismissDisabled()
      }
  }
}
