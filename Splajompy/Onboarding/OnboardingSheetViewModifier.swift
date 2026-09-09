import PostHog
import SwiftUI

struct OnboardingSheetViewModifier: ViewModifier {
  @AppStorage("image_layout_preference") private var imageLayoutPreference: ImageLayoutPreference =
    .undecided
  @State private var stagedImageLayoutPreference: ImageLayoutPreference =
    .undecided

  @AppStorage("hasCompletedPushNotificationOnboarding") private
    var hasCompletedPushNotificationOnboarding: Bool = false

  @AppStorage("hasViewedSplajompartyInvite09252026") private
    var hasViewedSplajompartyInvite: Bool = false

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

  var shouldShowSplajomparty: Bool {
    !hasViewedSplajompartyInvite
      && PostHogSDK.shared.isFeatureEnabled("splajomparty-invite-09252026")
  }

  func body(content: Content) -> some View {
    content
      .sheet(
        isPresented: .constant(
          shouldShowSplajomparty
            && !(shouldShowImageOnboarding || shouldShowNotificationsOnboarding)
        )
      ) {
        PartyInviteView(onDismiss: { hasViewedSplajompartyInvite = true })
      }
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
