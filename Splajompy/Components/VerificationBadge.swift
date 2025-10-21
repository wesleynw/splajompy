import PostHog
import SwiftUI

struct VerificationBadge: View {
  var body: some View {
      if PostHogSDK.shared.isFeatureEnabled("verification-badges") || true {
        Image(systemName: "checkmark.seal.fill")
          .foregroundColor(.blue)
          .font(.caption)
      }
  }
}
