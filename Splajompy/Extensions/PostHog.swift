import PostHog

/// Initializes PostHog SDK, which handles feature flags, events, telemetry, e.g.
func initializePostHog() {
  let phProjectToken = "phc_sSDHxTCqpjwoSDSOQiNAAgmybjEakfePBsaNHWaWy74"
  let config = PostHogConfig(projectToken: phProjectToken)
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
