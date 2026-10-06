import PostHog
import SwiftUI

struct CaughtUpView: View {
  var onContinue: () -> Void

  @State private var isAppeared: Bool = false

  var body: some View {
    VStack {
      Image(systemName: "checkmark.circle")
        .resizable()
        .frame(width: 50, height: 50)
      Text("You're all caught up")
        .font(SJFont.title3)
        .padding()

      Button {
        PostHogSDK.shared.capture("caught_up_continue")
        onContinue()
      } label: {
        Text("See older posts?")
          .font(SJFont.body)
          .modify {
            if #available(iOS 26, macOS 26, *) {
              $0.buttonStyle(.glass)
            } else {
              $0.buttonStyle(.bordered)
            }
          }
      }
    }
    .padding()
    .modify {
      if #available(iOS 26, macOS 26, *) {
        $0.symbolEffect(.drawOn, isActive: !isAppeared)
      }
    }
    .onAppear {
      isAppeared = true
    }
  }
}

#Preview {
  CaughtUpView(onContinue: {})
}
