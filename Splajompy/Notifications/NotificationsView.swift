import Kingfisher
import SwiftUI

struct NotificationsView: View {
  @State private var path = NavigationPath()
  @StateObject private var viewModel: ViewModel

  @EnvironmentObject private var authManager: AuthManager
  @EnvironmentObject private var feedRefreshManager: FeedRefreshManager

  init(viewModel: ViewModel = ViewModel()) {
    _viewModel = StateObject(wrappedValue: viewModel)
  }

  var body: some View {
    NavigationStack(path: $path) {
      ZStack {
        ScrollView {
          switch viewModel.state {
          case .idle:
            Color.clear
          case .loading:
            ProgressView()
              .scaleEffect(1.5)
              .frame(maxWidth: .infinity)
              .frame(maxHeight: .infinity)
          case .loaded(let notifications):
            if notifications.isEmpty {
              Text("No notifications.")
                .font(.title3)
                .fontWeight(.bold)
                .padding(.top, 40)
            } else {
              NotificationsList(
                viewModel: viewModel,
                notifications: notifications
              )
              .environmentObject(feedRefreshManager)
            }
          case .failed(let error):
            VStack {
              Text("Something went wrong")
                .font(.title3)
                .fontWeight(.bold)
                .padding()
              Text(error.localizedDescription)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.red)
              Image(systemName: "arrow.clockwise")
                .imageScale(.large)
                .onTapGesture {
                  Task { @MainActor in
                    await viewModel.loadNotifications(reset: true)
                  }
                }
                .padding()
            }
          }
        }
        .refreshable(action: {
          Task { await viewModel.loadNotifications(reset: true) }
        })
      }
      .onAppear {
        Task {
          await viewModel.loadNotifications()
        }
      }
      .toolbar {
        Button {
          viewModel.markAllNotificationsAsRead()
        } label: {
          Image(systemName: "text.badge.checkmark")
        }
        .buttonStyle(.plain)
      }
      .navigationTitle("Notifications")
      .onOpenURL { url in
        if let route = parseDeepLink(url) {
          path.append(route)
        }
      }
      .navigationDestination(for: Route.self) { route in
        switch route {
        case .profile(let id, let username):
          ProfileView(userId: Int(id)!, username: username)
        }
      }
      .environmentObject(authManager)
      .environmentObject(feedRefreshManager)
    }
  }
}

struct NotificationsList: View {
  @ObservedObject private var viewModel: NotificationsView.ViewModel
  let notifications: [Notification]
  @EnvironmentObject private var feedRefreshManager: FeedRefreshManager

  init(viewModel: NotificationsView.ViewModel, notifications: [Notification]) {
    self.viewModel = viewModel
    self.notifications = notifications
  }

  var body: some View {
    LazyVStack {
      ForEach(notifications) { notification in
        NotificationRow(notification: notification)
          .swipeActions(edge: .leading) {
            Button {
              viewModel.markNotificationAsRead(for: notification)
            } label: {
              VStack {
                Image(systemName: "checkmark.circle")
                Text("Mark Done")
              }
            }
            .tint(.blue)
          }
          .environmentObject(feedRefreshManager)
          .onAppear {
            if viewModel.canLoadMore
              && notification.id == notifications.last?.id
            {
              Task { await viewModel.loadNotifications() }
            }
          }
      }
    }
    .padding()
  }
}

struct NotificationRow: View {
  @EnvironmentObject private var feedRefreshManager: FeedRefreshManager
  let notification: Notification

  let formatter = RelativeDateTimeFormatter()

  private var notificationDate: Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.date(from: notification.createdAt) ?? Date()
  }

  var body: some View {
    Group {
      if notification.post != nil || notification.comment != nil {
        NavigationLink {
          if let post = notification.post {
            StandalonePostView(postId: post.postId)
          } else if let comment = notification.comment {
            CommentsView(postId: comment.postId)
          }
        } label: {
          notificationContent
        }
        .buttonStyle(.plain)
      } else {
        notificationContent
      }
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
            ContentTextView(text: notification.message, facets: notification.facets ?? [])
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
              .resizable()
              .frame(width: 40, height: 40)
              .cornerRadius(5)
          }
        }

        if let comment = notification.comment {
          MiniNotificationView(text: comment.text)
        } else if let post = notification.post, let text = post.text, text.count > 0 {
          MiniNotificationView(text: text)
        }
      }
    }
    .padding(.vertical, 4)
  }
}

struct NotificationsView_Previews: PreviewProvider {
  static var feedRefreshManager = FeedRefreshManager()

  static var previews: some View {
    Group {
      NotificationsView(viewModel: createViewModel(state: .loaded))
        .environmentObject(feedRefreshManager)
        .previewDisplayName("Loaded")

      NotificationsView(viewModel: createViewModel(state: .empty))
        .environmentObject(feedRefreshManager)
        .previewDisplayName("Empty")

      NotificationsView(viewModel: createViewModel(state: .loading))
        .environmentObject(feedRefreshManager)
        .previewDisplayName("Loading")

      NotificationsView(viewModel: createViewModel(state: .error))
        .environmentObject(feedRefreshManager)
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
