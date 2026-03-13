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
              withAnimation(.spring) {
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
          .allowsHitTesting(filter == filterOption || filter == .all)
        }
      }
      .padding(4)
    }
    .scrollIndicators(.hidden)
    .scrollDisabled(filter != .all)
    .overlay(alignment: .leading) {
      if filter != .all {
        HStack(spacing: 5) {
          Button(action: {
            withAnimation(.spring) { filter = .all }
          }) {
            Image(systemName: "xmark")
              .font(.callout)
              .fontWeight(.semibold)
              .frame(maxWidth: .infinity, maxHeight: .infinity)
              .aspectRatio(1, contentMode: .fit)
              .background(.regularMaterial, in: .circle)
          }
          .buttonStyle(.plain)

          FilterCapsule(
            title: filter.displayName,
            isActive: filter == .all,
            onTap: {
              withAnimation(.spring) { filter = .all }
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
  @Previewable @State var filter: NotificationFilter = .mention

  NotificationBreadcrumbFilter(filter: $filter)
}
