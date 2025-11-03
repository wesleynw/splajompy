import SwiftUI

struct NotificationFilterMenu: View {
  @Binding var filter: NotificationFilter

  var body: some View {
    Menu {
      ForEach(NotificationFilter.allCases) { filterOption in
        Toggle(
          isOn: Binding(
            get: { filter == filterOption },
            set: { isOn in
              if isOn {
                filter = filterOption
              }
            }
          )
        ) {
          Label(
            filterOption.displayName,
            systemImage: NotificationIcon.iconName(for: filterOption.rawValue)
          )
        }
      }
    } label: {
      Image(
        systemName: "line.3.horizontal.decrease"
      )
      .foregroundStyle(filter == .all ? Color.primary : Color.white)
      .padding(8)
      .background(
        Circle()
          .fill(filter == .all ? Color.clear : Color.blue)
      )
    }
  }
}
