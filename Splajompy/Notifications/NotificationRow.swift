import SwiftUI

struct NotificationRow: View {
  let notification: Notification

  var body: some View {
    if let postId = notification.postId,
      notification.notificationType == "like",
      notification.hasNotificationActors == true
    {
      NavigationLink(
        value: Route.notificationActorsList(
          notificationId: notification.id,
          postId: postId
        )
      ) {
        notificationContent
      }
    } else if let postId = notification.postId {
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
    HStack(alignment: .center, spacing: 10) {
      NotificationIcon.icon(for: notification.notificationType)
        .frame(width: 28, height: 28)

      VStack(alignment: .leading, spacing: 4) {
        HStack(alignment: .top, spacing: 8) {
          VStack(alignment: .leading, spacing: 4) {
            Text(notification.richContent)

            TimelineView(.periodic(from: .now, by: 5)) { _ in
              Text(
                notification.createdAt.formatted(
                  .relative(presentation: .named)
                )
              )
              .font(.caption)
              .foregroundStyle(.secondary)
            }
          }

          if let blobUrl = notification.imageBlob {
            Spacer(minLength: 0)

            NotificationImageView(
              url: blobUrl
            )
            .frame(width: 40, height: 40)
          }
        }

        if let comment = notification.comment, !comment.text.isEmpty {
          MiniNotificationView(text: comment.text)
        } else if let post = notification.post, let text = post.text,
          !text.isEmpty
        {
          MiniNotificationView(text: text)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, 12)
  }
}

#Preview {
  NotificationRow(
    notification: Mocks.notification
  )
  .padding()
}
