import SwiftUI

private let filterOptions: [NotificationFilter] = [
  .mention, .comment, .like, .followers, .poll, .announcement,
]

struct NotificationBreadcrumbFilter: View {
  @Binding var filter: NotificationFilter
  @Namespace private var namespace

  var body: some View {
    ScrollView(.horizontal) {
      HStack(spacing: 5) {
        ForEach(filterOptions) { filterOption in
          FilterCapsule(
            title: filterOption.displayName,
            isActive: filter == filterOption,
            onTap: {
              withAnimation(.bouncy) {
                if filter == .all {
                  filter = filterOption
                } else {
                  filter = .all
                }
              }
            }
          )
          .matchedGeometryEffect(
            id: filter == filterOption ? "active" : "",
            in: namespace,
            isSource: false
          )
          .opacity(filter == .all || filter == filterOption ? 1 : 0)
        }
      }
      .padding(4)
    }
    .allowsHitTesting(filter == .all)
    .scrollIndicators(.hidden)
    .scrollDisabled(filter != .all)
    .overlay(alignment: .leading) {
      if filter != .all {
        HStack(spacing: 5) {
          Button(action: {
            withAnimation(.bouncy) { filter = .all }
          }) {
            Image(systemName: "xmark")
              .font(.callout)
              .fontWeight(.semibold)
              .padding(14)
              .contentShape(.circle)
          }
          .buttonStyle(.plain)
          .background(.regularMaterial, in: .circle)

          FilterCapsule(
            title: filter.displayName,
            isActive: filter == .all,
            onTap: {
              withAnimation(.bouncy) { filter = .all }
            }
          )
          .opacity(0)
          .allowsHitTesting(false)
          .matchedGeometryEffect(id: "active", in: namespace)
        }
        .padding(4)
        .padding(.leading, 10)
        .transition(.move(edge: .leading).combined(with: .opacity))
      }
    }
    .sensoryFeedback(.impact, trigger: filter)
  }
}

#Preview {
  @Previewable @State var filter: NotificationFilter = .all

  NotificationBreadcrumbFilter(filter: $filter)
}
