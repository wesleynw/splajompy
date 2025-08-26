import SwiftUI

struct NotificationRow: View {
  let notification: Notification
  let refreshId: UUID

  private func relativeDate(from createdAt: String) -> String {
    let date = sharedISO8601Formatter.date(from: createdAt) ?? Date()
    return sharedRelativeDateTimeFormatter.localizedString(
      for: date,
      relativeTo: Date()
    )
  }

  var body: some View {
    if let postId = notification.postId {
      NavigationLink(value: Route.post(id: postId)) {
        notificationContent
      }
    } else if let userId = notification.targetUserId,
      let username = notification.targetUserUsername
    {
      NavigationLink(
        value: Route.profile(id: String(userId), username: username)
      ) {
        notificationContent
      }
    } else {
      notificationContent
    }
  }

  private var notificationContent: some View {
    HStack(alignment: .top, spacing: 10) {
      NotificationIcon.icon(for: notification.notificationType)
        .frame(width: 28, height: 28)

      VStack(alignment: .leading, spacing: 4) {
        HStack(alignment: .top, spacing: 8) {
          VStack(alignment: .leading, spacing: 4) {
            ContentTextView(attributedText: notification.richContent)

            Text(relativeDate(from: notification.createdAt))
              .font(.caption)
              .foregroundColor(.secondary)
          }

          Spacer(minLength: 0)

          if let blobUrl = notification.imageBlob {
            NotificationImageView(
              url: blobUrl
            )
            .frame(width: 40, height: 40)
          }
        }

        if let comment = notification.comment {
          MiniNotificationView(text: comment.text)
        } else if let post = notification.post, let text = post.text,
          !text.isEmpty
        {
          MiniNotificationView(text: text)
        }
      }
    }
    .padding(.vertical, 12)
    .listRowSeparator(.visible)
    .listRowSeparatorTint(.secondary.opacity(0.3))
  }
}
