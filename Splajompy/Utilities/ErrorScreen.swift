import PostHog
import SwiftUI

struct ErrorScreen: View {
  let errorString: String
  let onRetry: () async -> Void
  @State private var isRetrying = false

  var body: some View {
    VStack {
      VStack {
        Text(errorString)
          .fontWeight(.bold)
          .foregroundStyle(.red)
      }
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
      PostHogSDK.shared.capture(
        "error_screen_shown",
        properties: ["message": errorString]
      )
    }
  }
}

#Preview {
  ErrorScreen(
    errorString: "Could not connect to the server",
    onRetry: { print("retrying") }
  )
}
