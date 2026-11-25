import PostHog
import SwiftUI

struct ErrorScreen: View {
  let errorString: String
  var source: String? = nil
  let onRetry: () async -> Void
  @State private var isRetrying = false

  var body: some View {
    VStack {
      Image("snail-alert")
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 200, height: 200)

      Text(errorString)
        .font(SFont.sized(to: .title3, weight: .bold))
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)

      Button {
        Task {
          isRetrying = true
          await onRetry()
          isRetrying = false
        }
      } label: {
        HStack {
          if isRetrying {
            ProgressView()
              .scaleEffect(0.8)
              #if os(macOS)
                .controlSize(.small)
              #endif
          } else {
            Image(systemName: "arrow.clockwise")
          }
          Text("Retry")
            .font(SFont.sized(to: .body, weight: .bold))
        }
      }
      .disabled(isRetrying)
      .modify {
        if #available(iOS 26, macOS 26, *) {
          $0.buttonStyle(.glass)
        } else {
          $0.buttonStyle(.borderless)
        }
      }
      .padding()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    .padding()
    .onAppear {
      var properties: [String: Any] = ["message": errorString]
      if let source { properties["source"] = source }
      PostHogSDK.shared.capture("error_screen_shown", properties: properties)
    }
  }
}

#Preview {
  ErrorScreen(
    errorString:
      "Could not connect to the server. Something went super wrong. Oh no! It's 100% completely broken. This error string is way too long too!",
    onRetry: { print("retrying") }
  )
}
