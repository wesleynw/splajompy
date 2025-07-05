import SwiftUI

struct NotificationRow: View {
  let notification: Notification
  let isUnread: Bool
  let onMarkAsRead: () -> Void

  var body: some View {
    Group {
      if let postId = notification.postId {
        NavigationLink(value: Route.post(id: postId)) {
          notificationContent
        }
        .buttonStyle(.plain)
      } else {
        notificationContent
      }
    }
    .swipeActions(edge: .leading) {
      if isUnread {
        Button {
          onMarkAsRead()
        } label: {
          Label("Mark Read", systemImage: "checkmark.circle")
        }
        .tint(.blue)
      }
    }
  }

  private var notificationContent: some View {
    ZStack {
      Color(UIColor.systemBackground)

      HStack(alignment: .top, spacing: 0) {
        NotificationIcon.icon(for: notification.notificationType)
          .font(.system(size: 20, weight: .medium))
          .foregroundColor(.white)
          .frame(width: 28, height: 28, alignment: .center)
          .padding(.leading, 16)
          .padding(.top, 14)

        VStack(alignment: .leading, spacing: 0) {
          HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
              ContentTextView(attributedText: processedContent)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 12)
                .padding(.top, 12)

              Text(displayDate)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 12)
                .padding(.top, 4)
            }

            Spacer(minLength: 0)

            if let blobUrl = notification.imageBlob,
              let imageWidth = notification.imageWidth,
              let imageHeight = notification.imageHeight
            {
              NotificationImageView(url: blobUrl, width: imageWidth, height: imageHeight)
                .frame(width: 40, height: 40)
                .padding(.trailing, 16)
                .padding(.top, 12)
            }
          }

          if let comment = notification.comment {
            MiniNotificationView(text: comment.text)
              .padding(.leading, 12)
              .padding(.top, 8)
              .padding(.trailing, 16)
          } else if let post = notification.post, let text = post.text, !text.isEmpty {
            MiniNotificationView(text: text)
              .padding(.leading, 12)
              .padding(.top, 8)
              .padding(.trailing, 16)
          }
        }
      }
      .padding(.bottom, 12)
    }
  }

  private var processedContent: AttributedString {
    let processedText = ContentTextView.processText(
      notification.message,
      facets: notification.facets ?? []
    )

    return
      (try? AttributedString(
        markdown: processedText,
        options: AttributedString.MarkdownParsingOptions(
          interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
      )) ?? AttributedString(notification.message)
  }

  private var displayDate: String {
    let date = sharedISO8601Formatter.date(from: notification.createdAt) ?? Date()
    return sharedRelativeDateTimeFormatter.localizedString(for: date, relativeTo: Date())
  }
}
