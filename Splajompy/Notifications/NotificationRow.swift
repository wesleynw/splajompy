import SwiftUI

struct NotificationRow: View {
  let notification: Notification

  var route: Route? {
    if let postId = notification.postId,
      notification.notificationType == "like",
      notification.hasNotificationActors == true
    {
      return .notificationActorsList(
        notificationId: notification.id,
        postId: postId
      )
    } else if let postId = notification.postId {
      return .post(id: postId)
    } else if let userId = notification.targetUserId,
      let username = notification.targetUserUsername
    {
      return .profile(id: String(userId), username: username)
    } else {
      return nil
    }
  }

  var body: some View {
    let content = VStack {
      notificationContent
      Divider()
    }
    .contentShape(.rect)

    if let route {
      NavigationLink(value: route) {
        content
      }
      .buttonStyle(.plain)
    } else {
      content
    }
  }

  private var notificationContent: some View {
    HStack(alignment: .center, spacing: 10) {
      Circle().frame(width: 10, height: 20)
        .foregroundStyle(notification.viewed ? .clear : .accentColor)

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
