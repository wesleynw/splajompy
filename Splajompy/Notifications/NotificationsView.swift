import Kingfisher
import SwiftUI

struct NotificationsView: View {
  @StateObject private var viewModel: ViewModel

  @EnvironmentObject private var authManager: AuthManager
  @EnvironmentObject private var feedRefreshManager: FeedRefreshManager

  init(viewModel: ViewModel = ViewModel()) {
    _viewModel = StateObject(wrappedValue: viewModel)
  }

  var body: some View {
    ZStack {
      switch viewModel.state {
      case .idle:
        Color.clear.onAppear {
          Task { await viewModel.loadNotifications(reset: true) }
        }
      case .loading:
        ProgressView()
          .scaleEffect(1.5)
          .frame(maxWidth: .infinity)
          .frame(maxHeight: .infinity)
      case .loaded(let notifications):
        if notifications.isEmpty {
          VStack {
            Spacer()
            Text("No notifications.")
              .font(.title3)
              .fontWeight(.bold)
              .padding(.top, 40)
            Button {
              Task { await viewModel.loadNotifications(reset: true) }
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
            ForEach(notifications) { notification in
              NotificationRow(viewModel: viewModel, notification: notification)
                .environmentObject(feedRefreshManager)
                .onAppear {
                  if viewModel.canLoadMore
                    && notification.notificationId
                      == notifications.last?.notificationId
                  {
                    Task { await viewModel.loadNotifications() }
                  }
                }
                .listRowInsets(
                  EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
                )
                .listRowSeparator(.hidden)
            }

            if viewModel.isLoadingMore {
              HStack {
                Spacer()
                ProgressView()
                  .scaleEffect(1.2)
                  .padding(.vertical, 8)
                Spacer()
              }
              .listRowInsets(
                EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
              )
              .listRowSeparator(.hidden)
            }
          }
          .listStyle(.plain)
          .refreshable {
            try? await Task.sleep(nanoseconds: 200_000_000)
            await viewModel.loadNotifications(reset: true)
          }
        }
      case .failed(let error):
        ErrorScreen(
          errorString: error.localizedDescription,
          onRetry: { await viewModel.loadNotifications(reset: true) })
      }

    }
    .toolbar {
      Button {
        viewModel.markAllNotificationsAsRead()
      } label: {
        HStack {
          Image(systemName: "text.badge.checkmark")
          Text("Mark Read")
        }
      }
      .buttonStyle(.bordered)
    }
    .navigationTitle("Notifications")
    .environmentObject(authManager)
    .environmentObject(feedRefreshManager)
  }
}

struct NotificationRow: View {
  @EnvironmentObject private var feedRefreshManager: FeedRefreshManager
  @ObservedObject private var viewModel: NotificationsView.ViewModel
  let notification: Notification

  let formatter = RelativeDateTimeFormatter()

  init(viewModel: NotificationsView.ViewModel, notification: Notification) {
    self.viewModel = viewModel
    self.notification = notification
  }

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
      Button {
        viewModel.markNotificationAsRead(for: notification)
      } label: {
        Label("Mark Read", systemImage: "checkmark.circle")
      }
      .tint(.blue)
    }
  }

  private var notificationContent: some View {
    HStack {
      Circle()
        .fill(notification.viewed ? Color.clear : Color.blue)
        .frame(width: 10, height: 10)

      VStack(alignment: .leading, spacing: 8) {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            ContentTextView(
              text: notification.message,
              facets: notification.facets ?? []
            )
            .environmentObject(feedRefreshManager)

            Text(
              formatter.localizedString(
                for: notificationDate,
                relativeTo: Date()
              )
            )
            .font(.caption)
            .foregroundColor(.gray)
          }

          Spacer()

          if let blobUrl = notification.imageBlob {
            KFImage(URL(string: blobUrl))
              .downsampling(size: CGSize.init(width: 40, height: 40))
              .resizable()
              .frame(width: 40, height: 40)
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
  static var feedRefreshManager = FeedRefreshManager()
  static var authManager = AuthManager()

  static var previews: some View {
    Group {
      NotificationsView(viewModel: createViewModel(state: .loaded))
        .environmentObject(feedRefreshManager)
        .environmentObject(authManager)
        .previewDisplayName("Loaded")

      NotificationsView(viewModel: createViewModel(state: .empty))
        .environmentObject(feedRefreshManager)
        .environmentObject(authManager)
        .previewDisplayName("Empty")

      NotificationsView(viewModel: createViewModel(state: .loading))
        .environmentObject(feedRefreshManager)
        .environmentObject(authManager)
        .previewDisplayName("Loading")

      NotificationsView(viewModel: createViewModel(state: .error))
        .environmentObject(feedRefreshManager)
        .environmentObject(authManager)
        .previewDisplayName("Error")
    }

  }

  static func createViewModel(state: MockState) -> NotificationsView.ViewModel {
    let mockService: MockNotificationService

    switch state {
    case .loaded:
      mockService = MockNotificationService(
        behavior: .success(
          MockNotificationService.createSampleNotifications(count: 10)
        )
      )

    case .empty:
      mockService = MockNotificationService(behavior: .success([]))

    case .loading:
      mockService = MockNotificationService(
        behavior: .delayed(
          MockNotificationService.createSampleNotifications(count: 10),
          10
        )
      )

    case .error:
      mockService = MockNotificationService(
        behavior: .failure(
          MockNotificationService.MockError("Network connection failed")
        )
      )
    }

    return NotificationsView.ViewModel(service: mockService)
  }

  enum MockState {
    case loaded
    case empty
    case loading
    case error
  }
}
