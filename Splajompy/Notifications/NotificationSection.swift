import SwiftUI

struct NotificationSection: View {
  let title: String
  let notifications: [Notification]
  let isUnread: Bool
  let isLoading: Bool
  let onMarkAsRead: (Int) -> Void
  let onMarkAllAsRead: () -> Void
  let onLoadMore: () -> Void

  var body: some View {
    Section {
      ForEach(notifications, id: \.notificationId) { notification in
        NotificationRow(
          notification: notification,
          isUnread: isUnread,
          onMarkAsRead: { onMarkAsRead(notification.notificationId) }
        )
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .transition(.opacity.combined(with: .move(edge: .top)))
        .onAppear {
          if notification.id == notifications.last?.id {
            onLoadMore()
          }
        }
      }

      if isLoading {
        HStack {
          Spacer()
          ProgressView()
            .scaleEffect(0.8)
          Spacer()
        }
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .padding(.vertical, 8)
      }
    } header: {
      HStack(spacing: 0) {
        Text(title)
          .font(.headline)
        Spacer(minLength: 0)
        if isUnread && !notifications.isEmpty {
          Button("Mark All Read") {
            onMarkAllAsRead()
          }
          .font(.caption)
          .foregroundColor(.blue)
          .buttonStyle(BorderlessButtonStyle())
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
    }
  }
}
