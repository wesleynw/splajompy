import SwiftUI

struct FollowButtonView: View {
  @Binding var isLoading: Bool
  var user: DetailedUser
  let onFollowToggle: (DetailedUser) async -> Void

  var body: some View {
    Button(action: {
      guard !isLoading else { return }
      Task {
        isLoading = true
        await onFollowToggle(user)
        isLoading = false
      }
    }) {
      if isLoading {
        ProgressView()
          .scaleEffect(0.8)
      } else {
        Text(user.isFollowing ? "Unfollow" : "Follow")
          .font(.caption)
          .fontWeight(.medium)
      }
    }
    .frame(width: 70)
    .padding(.vertical, 6)
    .background(
      user.isFollowing
        ? Color.gray.opacity(0.2).gradient : Color.accentColor.gradient
    )
    .foregroundStyle(user.isFollowing ? .accent : .white)
    .animation(.spring(duration: 0.15, bounce: 0.3), value: user.isFollowing)
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .buttonStyle(.plain)
    .disabled(isLoading)
  }
}

#Preview {
  @Previewable @State var isLoading: Bool = false

  FollowButtonView(
    isLoading: .constant(false),
    user: Mocks.testUser1,
    onFollowToggle: { _ in }
  )
}
