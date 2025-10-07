import SwiftUI

struct PostAuthorView: View {
  let user: User

  var body: some View {
    NavigationLink(
      value: Route.profile(
        id: String(user.userId),
        username: user.username
      )
    ) {
      VStack(alignment: .leading, spacing: 2) {
        if user.username == "ads" {
          HStack {
            Image(systemName: "medal")
            Text("Sponsored")
              .font(.subheadline)
              .fontWeight(.semibold)
          }
        } else {
          if let displayName = user.name, !displayName.isEmpty {
            Text(displayName)
              .font(.title2)
              .fontWeight(.black)
              .lineLimit(1)
            Text("@\(user.username)")
              .font(.subheadline)
              .fontWeight(.bold)
              .foregroundColor(.gray)
          } else {
            Text("@\(user.username)")
              .font(.title3)
              .fontWeight(.black)
          }
        }
      }
    }
    .buttonStyle(.plain)
  }
}
