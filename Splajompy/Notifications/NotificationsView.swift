import Kingfisher
import SwiftUI

struct NotificationsView: View {
  @StateObject private var viewModel = ViewModel()
  @EnvironmentObject private var authManager: AuthManager
  @EnvironmentObject private var feedRefreshManager: FeedRefreshManager

  var body: some View {
    Group {
      switch viewModel.state {
      case .idle, .loading:
        loadingPlaceholder
      case .loaded(let unread, let read):
        if unread.isEmpty && read.isEmpty {
          emptyStateView
        } else {
          notificationsList
        }
      case .failed(let error):
        ErrorScreen(
          errorString: error.localizedDescription,
          onRetry: { await viewModel.refreshNotifications() }
        )
      }
    }
    .navigationTitle("Notifications")
    .onAppear {
      if case .idle = viewModel.state {
        Task { await viewModel.refreshNotifications() }
      }
    }
  }

  private var loadingPlaceholder: some View {
    VStack {
      Spacer()
      ProgressView()
        .scaleEffect(1.5)
        .padding()
      Spacer()
    }
  }

  private var emptyStateView: some View {
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
  }

  private var notificationsList: some View {
    List {
      if !viewModel.unreadNotifications.isEmpty {
        notificationSection(
          title: "Unread", notifications: viewModel.unreadNotifications, isUnread: true)
      }

      if !viewModel.readNotifications.isEmpty && !viewModel.canLoadMoreUnread {
        notificationSection(
          title: "Read", notifications: viewModel.readNotifications, isUnread: false)
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

  private func notificationSection(title: String, notifications: [Notification], isUnread: Bool)
    -> some View
  {
    Section {
      ForEach(notifications) { notification in
        NotificationRow(notification: notification, isUnread: isUnread)
          .onAppear {
            guard notification.id == notifications.last?.id else { return }
            Task {
              if isUnread {
                await viewModel.loadMoreUnreadNotifications()
                if !viewModel.canLoadMoreUnread && viewModel.readNotifications.isEmpty {
                  await viewModel.loadMoreReadNotifications()
                }
              } else {
                await viewModel.loadMoreReadNotifications()
              }
            }
          }
      }

      if (isUnread && viewModel.isLoadingMoreUnread) || (!isUnread && viewModel.isLoadingMoreRead) {
        ProgressView()
          .frame(maxWidth: .infinity, alignment: .center)
          .listRowSeparator(.hidden)
      }
    } header: {
      HStack {
        Text(title)
          .font(.headline)
        Spacer()
        if isUnread && !notifications.isEmpty {
          Button("Mark All Read") {
            Task { await viewModel.markAllNotificationsAsRead() }
          }
          .font(.caption)
          .foregroundColor(.blue)
          .buttonStyle(BorderlessButtonStyle())
        }
      }
    }
  }
}

struct NotificationRow: View {
  @EnvironmentObject private var viewModel: NotificationsView.ViewModel
  @EnvironmentObject private var feedRefreshManager: FeedRefreshManager
  let notification: Notification
  let isUnread: Bool

  private var notificationDate: Date {
    ISO8601DateFormatter().date(from: notification.createdAt) ?? Date()
  }

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
          Task {
            await viewModel.markNotificationAsRead(notificationId: notification.notificationId)
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
      NotificationIcon.icon(for: notification.notificationType)
        .font(.system(size: 20))
        .foregroundColor(.white)
        .frame(width: 28, height: 28)

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
            notificationImage(url: blobUrl, width: imageWidth, height: imageHeight)
          }
        }

        if let comment = notification.comment {
          MiniNotificationView(text: comment.text)
        } else if let post = notification.post, let text = post.text, !text.isEmpty {
          MiniNotificationView(text: text)
        }
      }
    }
    .padding(.vertical, 4)
  }

  private func notificationImage(url: String, width: Int32, height: Int32) -> some View {
    NotificationImageView(url: url, width: width, height: height)
  }
}

struct NotificationImageView: View {
  let url: String
  let width: Int32
  let height: Int32

  private let targetSize: CGFloat = 40

  var body: some View {
    let scale = UIScreen.main.scale
    let targetPixelSize = targetSize * scale
    let aspectRatio = CGFloat(width) / CGFloat(height)

    KFImage(URL(string: url))
      .placeholder { ProgressView() }
      .setProcessor(
        DownsamplingImageProcessor(
          size: aspectRatio > 1
            ? CGSize(width: targetPixelSize * aspectRatio, height: targetPixelSize)
            : CGSize(width: targetPixelSize, height: targetPixelSize / aspectRatio)
        )
      )
      .resizable()
      .aspectRatio(contentMode: .fill)
      .frame(width: targetSize, height: targetSize)
      .clipped()
      .cornerRadius(5)
  }
}

struct NotificationsView_Previews: PreviewProvider {
  static var previews: some View {
    NotificationsView()
      .environmentObject(FeedRefreshManager())
      .environmentObject(AuthManager())
  }
}
