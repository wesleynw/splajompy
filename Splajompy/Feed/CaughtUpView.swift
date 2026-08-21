import SwiftUI

struct CaughtUpView: View {
  let onShowOlderPosts: () -> Void

  var body: some View {
    VStack(spacing: 8) {
      Image(systemName: "checkmark.circle")
        .font(.largeTitle)
        .foregroundStyle(.secondary)
      Text("You're all caught up")
        .font(SJFont.heading)
      Text("You've seen all new posts from the past 2 days.")
        .font(SJFont.body)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
      Button("Show older posts", action: onShowOlderPosts)
        .padding(.top, 4)
        .modify {
          if #available(iOS 26, macOS 26, *) {
            $0.buttonStyle(.glass)
          } else {
            $0.buttonStyle(.bordered)
          }
        }
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .center)
  }
}

#Preview {
  CaughtUpView(onShowOlderPosts: { print("show older posts") })
}
