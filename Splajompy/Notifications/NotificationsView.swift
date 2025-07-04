import Kingfisher
import SwiftUI

struct NotificationsView: View {
  @StateObject private var viewModel = ViewModel()
  @EnvironmentObject private var authManager: AuthManager
  @EnvironmentObject private var feedRefreshManager: FeedRefreshManager
  @State private var animationTrigger: UUID = UUID()

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
        ForEach(viewModel.readNotificationsByDateSection, id: \.key) { section in
          notificationSection(
            title: section.key.rawValue,
            notifications: section.value,
            isUnread: false
          )
        }
      }
    }
    .listStyle(.plain)
    .animation(.easeInOut(duration: 0.3), value: animationTrigger)
    .refreshable {
      await viewModel.refreshNotifications()
    }
    .environmentObject(viewModel)
    .onChange(of: viewModel.state) {
      animationTrigger = UUID()
    }
  }

  private func notificationSection(title: String, notifications: [Notification], isUnread: Bool)
    -> some View
  {
    Section {
      ForEach(notifications) { notification in
        NotificationRow(notification: notification, isUnread: isUnread)
          .listRowInsets(EdgeInsets())
          .listRowSeparator(.hidden)
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

      if (isUnread && viewModel.isLoadingMoreUnread)
        || (!isUnread && viewModel.isLoadingMoreRead && isLastReadSection(title: title))
      {
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
            Task { await viewModel.markAllNotificationsAsRead() }
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

  private func isLastReadSection(title: String) -> Bool {
    guard let lastSection = viewModel.readNotificationsByDateSection.last else { return false }
    return lastSection.key.rawValue == title
  }
}

struct NotificationRow: View {
  @EnvironmentObject private var viewModel: NotificationsView.ViewModel
  @EnvironmentObject private var feedRefreshManager: FeedRefreshManager
  let notification: Notification
  let isUnread: Bool

  private var notificationDate: Date {
    viewModel.parsedDate(for: notification.createdAt)
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
              ContentTextView(
                text: notification.message,
                facets: notification.facets ?? []
              )
              .environmentObject(feedRefreshManager)
              .fixedSize(horizontal: false, vertical: true)
              .padding(.leading, 12)
              .padding(.top, 12)

              Text(
                sharedRelativeDateTimeFormatter.localizedString(
                  for: notificationDate,
                  relativeTo: Date()
                )
              )
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
}

struct NotificationImageView: View {
  let url: String
  let width: Int32
  let height: Int32

  private static let targetSize: CGFloat = 40
  private static let scale = UIScreen.main.scale
  private static let targetPixelSize = targetSize * scale

  var body: some View {
    let aspectRatio = CGFloat(width) / CGFloat(height)
    let processorSize =
      aspectRatio > 1
      ? CGSize(width: Self.targetPixelSize * aspectRatio, height: Self.targetPixelSize)
      : CGSize(width: Self.targetPixelSize, height: Self.targetPixelSize / aspectRatio)

    KFImage(URL(string: url))
      .placeholder {
        Rectangle()
          .fill(Color.gray.opacity(0.3))
          .frame(width: Self.targetSize, height: Self.targetSize)
      }
      .setProcessor(DownsamplingImageProcessor(size: processorSize))
      .resizable()
      .aspectRatio(contentMode: .fill)
      .frame(width: Self.targetSize, height: Self.targetSize)
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
