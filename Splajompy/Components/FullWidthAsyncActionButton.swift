import SwiftUI

struct AsyncActionButton: View {
  let title: String
  let isLoading: Bool
  let isDisabled: Bool
  let isProminent: Bool = true
  let action: () async -> Void

  var body: some View {
    Button(action: { Task { await action() } }) {
      Text(title)
        .font(
          {
            #if os(iOS)
              SJFont.heading
            #else
              SJFont.body
            #endif
          }()
        )
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
      if #available(anyAppleOS 26, *) {
        if isProminent {
          $0.buttonStyle(.glassProminent)
        } else {
          $0.buttonStyle(.glass)
        }
      } else {
        if isProminent {
          $0.buttonStyle(.borderedProminent)
        } else {
          $0.buttonStyle(.bordered)
        }
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
