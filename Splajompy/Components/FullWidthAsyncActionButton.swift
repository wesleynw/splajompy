import SwiftUI

struct AsyncActionButton: View {
  let title: String
  let isLoading: Bool
  let isDisabled: Bool
  let action: () async -> Void

  var body: some View {
    Button(action: { Task { await action() } }) {
      Text(title)
        .font(SJFont.heading)
        .opacity(isLoading ? 0 : 1)
        .frame(maxWidth: .infinity)
        .overlay {
          if isLoading {
            ProgressView()
              .controlSize(.small)
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
    .frame(maxWidth: .infinity)
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
