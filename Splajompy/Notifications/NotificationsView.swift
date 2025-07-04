import Kingfisher
import SwiftUI

struct NotificationsView: View {
  @StateObject private var viewModel = ViewModel()

  @EnvironmentObject private var authManager: AuthManager
  @EnvironmentObject private var feedRefreshManager: FeedRefreshManager

  var body: some View {
    ZStack {
      if viewModel.isInitialLoading {
        ProgressView()
          .scaleEffect(1.5)
          .frame(maxWidth: .infinity)
          .frame(maxHeight: .infinity)
      } else if viewModel.unreadNotifications.isEmpty && viewModel.readNotifications.isEmpty {
        VStack {
          Spacer()
          Text("No notifications.")
            .font(.title3)
            .fontWeight(.bold)
            .padding(.top, 40)
          Button {
            Task { await viewModel.refreshNotifications() }
          } label: {
            HStack {
              Image(systemName: "arrow.clockwise")
              Text("Retry")
            }
          }
          .padding()
          .buttonStyle(.bordered)
          Spacer()
        }
      } else {
        List {
          if !viewModel.unreadNotifications.isEmpty {
            UnreadNotificationsSection()
          }

          if !viewModel.readNotifications.isEmpty || !viewModel.unreadNotifications.isEmpty {
            ReadNotificationsSection()
          }
        }
        .listStyle(.plain)
        .animation(.easeInOut(duration: 0.3), value: viewModel.unreadNotifications.count)
        .animation(.easeInOut(duration: 0.3), value: viewModel.readNotifications.count)
        .refreshable {
          await viewModel.refreshNotifications()
        }
        .environmentObject(viewModel)
      }
    }
    .navigationTitle("Notifications")
    .environmentObject(authManager)
    .environmentObject(feedRefreshManager)
    .onAppear {
      if viewModel.unreadNotifications.isEmpty && viewModel.readNotifications.isEmpty {
        Task { await viewModel.refreshNotifications() }
      }
    }
  }
}

struct UnreadNotificationsSection: View {
  @EnvironmentObject private var viewModel: NotificationsView.ViewModel

  var body: some View {
    Section {
      ForEach(viewModel.unreadNotifications) { notification in
        NotificationSectionRow(notification: notification) {
          await viewModel.markNotificationAsRead(notificationId: notification.notificationId)
        }
        .transition(
          .asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
          )
        )
        .onAppear {
          if notification.id == viewModel.unreadNotifications.last?.id {
            Task {
              await viewModel.loadMoreUnreadNotifications()
            }
          }
        }
      }

      if viewModel.isLoadingMoreUnread {
        ProgressView()
          .frame(maxWidth: .infinity, alignment: .center)
          .listRowSeparator(.hidden)
      }
    } header: {
      HStack {
        Text("Unread")
          .font(.headline)

        Spacer()

        if !viewModel.unreadNotifications.isEmpty {
          Button(action: {
            Task {
              await viewModel.markAllNotificationsAsRead()
            }
          }) {
            HStack(spacing: 4) {
              Image(systemName: "checkmark")
                .font(.caption)
              Text("Mark All Read")
                .font(.caption)
            }
            .foregroundColor(.blue)
          }
          .buttonStyle(BorderlessButtonStyle())
        }
      }
    }
  }
}

struct ReadNotificationsSection: View {
  @EnvironmentObject private var viewModel: NotificationsView.ViewModel

  var body: some View {
    Section {
      ForEach(viewModel.readNotifications) { notification in
        NotificationSectionRow(notification: notification) {
          // Read notifications cannot be marked as read again
        }
        .transition(
          .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
          )
        )
        .onAppear {
          if notification.id == viewModel.readNotifications.last?.id {
            Task {
              await viewModel.loadMoreReadNotifications()
            }
          }
        }
      }

      if viewModel.isLoadingMoreRead {
        ProgressView()
          .frame(maxWidth: .infinity, alignment: .center)
          .listRowSeparator(.hidden)
      }
    } header: {
      Text("Read")
        .font(.headline)
    }
  }
}

struct NotificationSectionRow: View {
  @EnvironmentObject private var feedRefreshManager: FeedRefreshManager
  let notification: Notification
  let onMarkAsRead: () async -> Void

  private var notificationDate: Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.date(from: notification.createdAt) ?? Date()
  }

  var body: some View {
    ZStack {
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
      if !notification.viewed {
        Button {
          Task {
            await onMarkAsRead()
          }
        } label: {
          Label("Mark Read", systemImage: "checkmark.circle")
        }
        .tint(.blue)
      }
    }
  }

  private var notificationContent: some View {
    HStack {
      VStack {
        NotificationIcon.icon(for: notification.notificationType)
          .font(.system(size: 20))
          .foregroundColor(.white)
          .frame(width: 28, height: 28)
      }
      .frame(width: 28)

      VStack(alignment: .leading, spacing: 8) {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            ContentTextView(
              text: notification.message,
              facets: notification.facets ?? []
            )
            .environmentObject(feedRefreshManager)

            Text(
              RelativeDateTimeFormatter().localizedString(
                for: notificationDate,
                relativeTo: Date()
              )
            )
            .font(.caption)
            .foregroundColor(.gray)
          }

          Spacer()

          if let blobUrl = notification.imageBlob,
            let imageWidth = notification.imageWidth,
            let imageHeight = notification.imageHeight
          {
            let targetSize: CGFloat = 40
            let scale = UIScreen.main.scale
            let targetPixelSize = targetSize * scale
            let aspectRatio = CGFloat(imageWidth) / CGFloat(imageHeight)

            KFImage(URL(string: blobUrl))
              .placeholder {
                ProgressView()
              }
              .setProcessor(
                DownsamplingImageProcessor(
                  size: aspectRatio > 1
                    ? CGSize(
                      width: targetPixelSize * aspectRatio,
                      height: targetPixelSize
                    )
                    : CGSize(
                      width: targetPixelSize,
                      height: targetPixelSize / aspectRatio
                    )
                )
              )
              .resizable()
              .aspectRatio(contentMode: .fill)
              .frame(width: targetSize, height: targetSize)
              .clipped()
              .cornerRadius(5)
          }
        }

        if let comment = notification.comment {
          MiniNotificationView(text: comment.text)
        } else if let post = notification.post, let text = post.text,
          text.count > 0
        {
          MiniNotificationView(text: text)
        }
      }
    }
    .padding(.vertical, 4)
  }
}

struct NotificationsView_Previews: PreviewProvider {
  static var previews: some View {
    NotificationsView()
      .environmentObject(FeedRefreshManager())
      .environmentObject(AuthManager())
  }
}
