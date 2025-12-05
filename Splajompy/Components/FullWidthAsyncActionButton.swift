import SwiftUI

struct AsyncActionButton: View {
  let title: String
  let isLoading: Bool
  let isDisabled: Bool
  let action: () async -> Void

  var body: some View {
    Button(action: { Task { await action() } }) {
      Text(title)
        .fontWeight(.bold)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .trailing) {
          if isLoading {
            ProgressView()
              .tint(.white)
              .scaleEffect(0.65)
          }
        }
    }
    .controlSize(.large)
    .modify {
      if #available(iOS 26, macOS 26, *) {
        $0.buttonStyle(.glassProminent)
      } else {
        $0.buttonStyle(.borderedProminent)
      }
    }
    .disabled(isLoading || isDisabled)
  }
}

#Preview {
  AsyncActionButton(
    title: "Test Button",
    isLoading: false,
    isDisabled: false,
    action: {}
  )
  .padding()
}
