import SwiftUI

let filterOptions: [NotificationFilter] = [
  .mention, .like, .comment, .followers, .poll,
]

struct NotificationBreadcrumbFilter: View {
  @Binding var filter: NotificationFilter

  var body: some View {
    ScrollView(.horizontal) {
      HStack(alignment: .center, spacing: 5) {
        if filter != .all {
          Button(action: {
            filter = .all
          }) {
            Image(systemName: "xmark")
              .font(.callout)
              .fontWeight(.semibold)
          }
          .buttonStyle(.plain)
          .padding(.trailing, 5)
          .transition(.move(edge: .leading).combined(with: .opacity))
        }

        ForEach(filterOptions) { filterOption in
          if filter == .all || filter == filterOption {
            Button(action: {
              filter = filterOption
            }) {
              Text(filterOption.displayName)
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                  filter == filterOption ? .blue.opacity(0.66) : .clear
                )
                .background(.regularMaterial, in: .capsule)

            }
            .buttonStyle(.plain)
            .transition(
              .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .opacity
              )
            )
          }
        }
      }
      .padding(4)
      .animation(.spring, value: filter)
    }
    .scrollIndicators(.hidden)
  }
}

#Preview {
  @Previewable @State var filter: NotificationFilter = .all

  NotificationBreadcrumbFilter(filter: $filter)
    .padding()
}
