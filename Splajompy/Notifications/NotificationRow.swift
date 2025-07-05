import SwiftUI

struct NotificationRow: View {
  let notification: Notification

  var body: some View {
    Group {
      if let postId = notification.postId {
        NavigationLink(value: Route.post(id: postId)) {
          notificationContent
        }
      } else {
        notificationContent
      }
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

            Text(notification.relativeDate)
              .font(.caption)
              .foregroundColor(.secondary)
          }

          Spacer(minLength: 0)

          if let blobUrl = notification.imageBlob,
            let imageWidth = notification.imageWidth,
            let imageHeight = notification.imageHeight
          {
            NotificationImageView(
              url: blobUrl,
              width: imageWidth,
              height: imageHeight
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
