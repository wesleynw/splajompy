import SwiftUI

struct ProfileActionsMenu: View {
  var isBlocking: Bool
  var isMuting: Bool
  var username: String
  var onToggleBlock: () -> Void
  var onToggleMute: () -> Void

  var body: some View {
    Menu {
      if isBlocking {
        Button(role: .destructive, action: { onToggleBlock() }) {
          Label(
            "Unblock @\(username)",
            systemImage: "person.fill.checkmark"
          )
        }
      } else {
        Button(role: .destructive, action: { onToggleBlock() }) {
          Label(
            "Block @\(username)",
            systemImage: "person.fill.xmark"
          )
        }
      }

      if isMuting {
        Button(action: { onToggleMute() }) {
          Label(
            "Unmute @\(username)",
            systemImage: "speaker.wave.2"
          )
        }
      } else {
        Button(action: { onToggleMute() }) {
          Label(
            "Mute @\(username)",
            systemImage: "speaker.slash"
          )
          Text("Hide this person's posts.")
        }
      }
    } label: {
      Image(systemName: "ellipsis.circle")
    }
  }
}

#Preview {
  @Previewable @State var isBlocking: Bool = false
  @Previewable @State var isMuting: Bool = false

  ProfileActionsMenu(
    isBlocking: isBlocking,
    isMuting: isMuting,
    username: "wesley",
    onToggleBlock: {},
    onToggleMute: {}
  )
}
