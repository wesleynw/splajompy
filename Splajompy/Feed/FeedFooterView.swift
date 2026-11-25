import SwiftUI

struct FeedFooterView: View {
  let showCaughtUpBanner: Bool
  let canLoadMore: Bool

  var setHasReachedCaughtUp: () -> Void
  var continuePastCaughtUp: () -> Void

  var body: some View {
    VStack {
      if showCaughtUpBanner {
        CaughtUpView(onContinue: continuePastCaughtUp)
          .padding(.bottom, 20)
          .postHogScreenView()
          .onAppear {
            setHasReachedCaughtUp()
          }
      } else if canLoadMore {
        ProgressView()
          .padding(.bottom, 70)
          #if os(macOS)
            .controlSize(.small)
          #endif
          .frame(maxWidth: .infinity, alignment: .center)
      } else {
        VStack(spacing: 8) {
          Text("Is that the very first post?")
          Text("What came before that?")
          Text("Nothing at all?")
          HStack(spacing: 4) {
            Text("It always just")
            Text("Splajompy")
              .fontWeight(.black)
          }
        }
        .multilineTextAlignment(.center)
        .padding()
        .font(SFont.sized(to: .body, weight: .body))
      }
    }
    .padding()
    .frame(height: 400)
    .frame(maxWidth: .infinity, alignment: .top)
  }
}

#Preview {
  @Previewable @State var showCaughtUpBanner: Bool = false
  @Previewable @State var canLoadMore: Bool = false

  VStack {
    Toggle("Show caught up banner", isOn: $showCaughtUpBanner)
    Toggle("Can load more", isOn: $canLoadMore)

    FeedFooterView(
      showCaughtUpBanner: showCaughtUpBanner,
      canLoadMore: canLoadMore,
      setHasReachedCaughtUp: {},
      continuePastCaughtUp: {}
    )
  }
}
