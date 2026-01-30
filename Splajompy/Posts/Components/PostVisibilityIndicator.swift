import SwiftUI

/// Small indicator to be placed at the header of a post to show if it's coming from a special post visibility type.
struct PostVisibilityIndicator: View {
  let visibility: VisibilityType

  var body: some View {
    if visibility == .CloseFriends {
      HStack(spacing: 4) {
        Image(systemName: "star.circle.fill")
        Text("Friends")
      }
      .font(.caption)
      .foregroundStyle(.primary)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(Color.green.opacity(0.2), in: Capsule())
    }
  }
}

#Preview {
  PostVisibilityIndicator(visibility: .CloseFriends)
    .padding()
}
