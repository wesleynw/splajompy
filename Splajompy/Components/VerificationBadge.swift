import PostHog
import SwiftUI

struct VerificationBadge: View {
  var body: some View {
    if PostHogSDK.shared.isFeatureEnabled("verification-badges") {
      Image(systemName: "checkmark.seal.fill")
        .foregroundStyle(.blue)
        .font(.caption)
    }
  }
}
