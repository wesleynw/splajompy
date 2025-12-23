import SwiftUI

struct ControversialPollView: View {
  var data: WrappedData
  var onContinue: () -> Void

  @EnvironmentObject var authManager: AuthManager

  @State private var isShowingIntroText: Bool = true
  @State private var isShowingContinueButton: Bool = false
  @State private var modifiedPoll: Poll?

  var body: some View {
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
            authorId: authManager.getCurrentUser()!.userId,
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
        .buttonStyle(.borderedProminent)
      }
    }
    .padding()
    .onAppear {
      if var poll = data.controversialPoll {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
          withAnimation {
            poll.currentUserVote = nil
            modifiedPoll = poll
          }
        }
      }
    }
  }
}

#Preview {
  ControversialPollView(
    data: Mocks.wrappedData,
    onContinue: {}
  )
  .environmentObject(AuthManager())
}
