//import SwiftUI
//
//struct NotificationSection: View, Equatable {
//  let id: String
//  let title: String
//  let notifications: [Notification]
//  let isUnread: Bool
//  let isLoading: Bool
//  let isLastSection: Bool
//  let onMarkAsRead: (Int) -> Void
//  let onMarkAllAsRead: () -> Void
//  let onLoadMore: () -> Void
//
//  nonisolated static func == (lhs: NotificationSection, rhs: NotificationSection) -> Bool {
//    lhs.id == rhs.id &&
//    lhs.title == rhs.title &&
//    lhs.notifications.count == rhs.notifications.count &&
//    lhs.isUnread == rhs.isUnread &&
//    lhs.isLoading == rhs.isLoading &&
//    lhs.isLastSection == rhs.isLastSection &&
//    zip(lhs.notifications, rhs.notifications).allSatisfy { $0.notificationId == $1.notificationId }
//  }
//
//  var body: some View {
//    Section {
//      ForEach(notifications, id: \.notificationId) { notification in
//        NotificationRow(
//          notification: notification,
//          isUnread: isUnread,
//          onMarkAsRead: { onMarkAsRead(notification.notificationId) }
//        )
//        .listRowInsets(EdgeInsets())
//        .listRowSeparator(.hidden)
//        .listRowBackground(Color.clear)
//        .onAppear {
//          if isLastSection && notification.id == notifications.last?.id {
//            onLoadMore()
//          }
//        }
//      }
//
//      if isLoading {
//        HStack {
//          Spacer()
//          ProgressView()
//            .scaleEffect(0.8)
//          Spacer()
//        }
//        .listRowInsets(EdgeInsets())
//        .listRowSeparator(.hidden)
//        .padding(.vertical, 8)
//      }
//    } header: {
//      HStack(spacing: 0) {
//        Text(title)
//          .font(.headline)
//        Spacer(minLength: 0)
//        if isUnread && !notifications.isEmpty {
//          Button("Mark All Read") {
//            onMarkAllAsRead()
//          }
//          .font(.caption)
//          .foregroundColor(.blue)
//          .buttonStyle(BorderlessButtonStyle())
//        }
//      }
//      .padding(.horizontal, 16)
//      .padding(.vertical, 8)
//    }
//  }
//}
