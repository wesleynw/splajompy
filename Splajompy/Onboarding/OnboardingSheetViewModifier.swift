import PostHog
import SwiftUI

struct OnboardingSheetViewModifier: ViewModifier {
  @AppStorage("image_layout_preference") private var imageLayoutPreference: ImageLayoutPreference =
    .undecided
  @State private var stagedImageLayoutPreference: ImageLayoutPreference = .undecided

  @AppStorage("hasCompletedPushNotificationOnboarding") private
    var hasCompletedPushNotificationOnboarding: Bool = false

  @State private var isNavigationToPushNotificationOnboarding: Bool = false

  var shouldShowImageOnboarding: Bool {
    imageLayoutPreference == .undecided
  }
  var shouldShowNotificationsOnboarding: Bool {
    !hasCompletedPushNotificationOnboarding
      && PostHogSDK.shared.isFeatureEnabled(
        "push-notifications-onboarding"
      )
  }

  func body(content: Content) -> some View {
    content
      .sheet(
        isPresented: .constant(
          shouldShowImageOnboarding || shouldShowNotificationsOnboarding
        )
      ) {
        NavigationStack {
          if imageLayoutPreference == .undecided {
            ImageLayoutOnboardingView(
              onComplete: {
                if shouldShowNotificationsOnboarding {
                  isNavigationToPushNotificationOnboarding = true
                } else {
                  imageLayoutPreference = stagedImageLayoutPreference
                }
              },
              preference: $stagedImageLayoutPreference
            )
            .postHogScreenView()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(
              isPresented: $isNavigationToPushNotificationOnboarding
            ) {
              PushNotificationsOnboardingView(
                onComplete: {
                  hasCompletedPushNotificationOnboarding = true
                  imageLayoutPreference = stagedImageLayoutPreference
                }
              )
              .postHogScreenView()
              .toolbar(.hidden, for: .navigationBar)
            }
          } else {
            PushNotificationsOnboardingView(
              onComplete: {
                hasCompletedPushNotificationOnboarding = true
              }
            )
            .postHogScreenView()
            .toolbar(.hidden, for: .navigationBar)
          }
        }
        .interactiveDismissDisabled()
      }
  }
}
