import SwiftUI

struct ErrorScreen: View {
  let errorString: String
  let onRetry: () async -> Void
  @State private var isRetrying = false
  
  var body: some View {
    VStack {
      Spacer()
      VStack {
        Text("There was an error.")
          .font(.title2)
          .fontWeight(.bold)
        Text(errorString)
          .foregroundColor(.red)
          .multilineTextAlignment(.center)
      }
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
      .padding()
      .buttonStyle(.bordered)
      Spacer()
    }
  }
}
