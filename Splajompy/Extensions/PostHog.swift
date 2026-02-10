import PostHog

/// Initializes PostHog SDK, which handles feature flags, events, telemetry, e.g.
func initializePostHog() {
  let posthogApiKey = "phc_sSDHxTCqpjwoSDSOQiNAAgmybjEakfePBsaNHWaWy74"
  let config = PostHogConfig(apiKey: posthogApiKey)
  config.captureScreenViews = false

  #if os(iOS)
    config.sessionReplay = true
    config.sessionReplayConfig.screenshotMode = true
    config.sessionReplayConfig.maskAllTextInputs = false
  #endif

  #if DEBUG
    config.debug = true
  #endif

  PostHogSDK.shared.setup(config)
}
