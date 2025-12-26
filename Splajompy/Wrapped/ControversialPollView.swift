import SwiftUI

struct ControversialPollView: View {
  var data: WrappedData
  var onContinue: () -> Void
  @EnvironmentObject var authManager: AuthManager
  @State private var isShowingIntroText: Bool = true
  @State private var isShowingContinueButton: Bool = false
  @State private var modifiedPoll: Poll?

  var body: some View {
    ZStack {
      TopographicBackground()

      VStack {
        Text("You had some controversial opinions this year...")
          .padding()
          .font(.title2)
          .fontWeight(.bold)
          .multilineTextAlignment(.center)
          .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
              withAnimation {
                isShowingIntroText = false
              }
            }
          }
        if !isShowingIntroText {
          if let poll = modifiedPoll {
            PollView(
              poll: poll,
              authorId: authManager.getCurrentUser()?.userId ?? 0,
              onVote: { _ in }
            )
            .padding()
            .transition(.opacity)
            .onAppear {
              DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                if var updatedPoll = modifiedPoll {
                  withAnimation {
                    updatedPoll.currentUserVote =
                      data.controversialPoll?.currentUserVote
                    modifiedPoll = updatedPoll
                  }
                }
              }
              DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                  isShowingContinueButton = true
                }
              }
            }
          }
        }
      }
      .frame(maxHeight: .infinity)
      .overlay(alignment: .bottom) {
        if isShowingContinueButton {
          Button("Continue") {
            onContinue()
          }
          .fontWeight(.bold)
          .modify {
            if #available(iOS 26, *) {
              $0.buttonStyle(.glassProminent)
            } else {
              $0.buttonStyle(.borderedProminent)
            }
          }
          .buttonStyle(.borderedProminent)
        }
      }
      .padding()
    }
    .background(.yellow.gradient.secondary)
    .onAppear {
      if var poll = data.controversialPoll {
        poll.currentUserVote = nil
        modifiedPoll = poll
      }
    }
  }
}

struct TopographicBackground: View {
  var body: some View {
    Canvas { context, size in
      let contourCount = 80
      let spacing = size.height / CGFloat(contourCount)

      for i in 0..<contourCount {
        var path = Path()
        let baseY = CGFloat(i) * spacing

        path.move(to: CGPoint(x: 0, y: baseY))

        for x in stride(from: 0, through: size.width, by: 20) {
          let noise =
            sin(x / 30 + CGFloat(i) * 0.5) * 15 + cos(x / 50 - CGFloat(i) * 0.3)
            * 10
          let y = baseY + noise
          path.addLine(to: CGPoint(x: x, y: y))
        }

        context.stroke(
          path,
          with: .color(.primary.opacity(0.08)),
          lineWidth: 1.5
        )
      }
    }
    .ignoresSafeArea()
  }
}

#Preview {
  ControversialPollView(
    data: Mocks.wrappedData,
    onContinue: {}
  )
  .environmentObject(AuthManager())
}
