import SwiftUI

struct ControversialPollView: View {
  var data: WrappedData
  var currentUser: User
  var onComplete: () -> Void

  @State private var isShowingIntroText: Bool = false

  var body: some View {
    if isShowingIntroText {
      Text("asdf")
    }

    PollView(
      poll: data.controversialPoll!,
      authorId: currentUser.userId,
      onVote: { _ in },
      currentUser: currentUser
    )
  }
}

#Preview {
  ControversialPollView(
    data: Mocks.wrappedData,
    currentUser: Mocks.basicUser,
    onComplete: {}
  )
  .environmentObject(AuthManager())
}
