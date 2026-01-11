import SwiftUI

struct ErrorScreen: View {
  let errorString: String
  let onRetry: () async -> Void
  @State private var isRetrying = false

  var body: some View {
    VStack {
      VStack {
        Text("There was an error.")
          .fontWeight(.bold)
          .font(.title2)
        Text(errorString)
          .fontWeight(.semibold)
          .foregroundColor(.red)
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
  }
}

#Preview {
  ErrorScreen(
    errorString: "Could not connect to the server",
    onRetry: { print("retrying") }
  )
}
