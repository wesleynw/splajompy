import SwiftUI

private let filterOptions: [NotificationFilter] = [
  .mention, .comment, .like, .followers, .poll, .announcement,
]

struct NotificationBreadcrumbFilter: View {
  @Binding var filter: NotificationFilter

  var body: some View {
    ScrollView(.horizontal) {
      HStack(alignment: .center, spacing: 5) {
        if filter != .all {
          Button(action: {
            withAnimation(.spring) { filter = .all }
          }) {
            Image(systemName: "xmark")
              .font(.callout)
              .fontWeight(.semibold)
              .contentShape(.rect)
          }
          .padding()
          .buttonStyle(.plain)
          .background(.quaternary, in: .circle)
          .transition(.move(edge: .leading).combined(with: .opacity))
        }

        ForEach(filterOptions) { filterOption in
          if filter == .all || filter == filterOption {
            Button(action: {
              withAnimation(.spring) {
                if filter == filterOption {
                  filter = .all
                } else {
                  filter = filterOption
                }
              }
            }) {
              Text(filterOption.displayName)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .padding()
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
    }
    .scrollIndicators(.hidden)
    .sensoryFeedback(.impact, trigger: filter)
  }
}

#Preview {
  @Previewable @State var filter: NotificationFilter = .mention

  NotificationBreadcrumbFilter(filter: $filter)
}
