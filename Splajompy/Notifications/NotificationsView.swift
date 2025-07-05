import SwiftUI

struct NotificationsView: View {
  @StateObject private var viewModel = ViewModel()
  @EnvironmentObject private var authManager: AuthManager
  @EnvironmentObject private var feedRefreshManager: FeedRefreshManager

  var body: some View {
    Group {
      switch viewModel.state {
      case .idle, .loading:
        loadingView
      case .loaded:
        if viewModel.isEmpty {
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

  private var loadingView: some View {
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
        NotificationSection(
          title: "Unread",
          notifications: viewModel.unreadNotifications,
          isUnread: true,
          isLoading: false,
          onMarkAsRead: { notificationId in
            Task { await viewModel.markNotificationAsRead(notificationId: notificationId) }
          },
          onMarkAllAsRead: {
            Task { await viewModel.markAllNotificationsAsRead() }
          },
          onLoadMore: {
            Task { await viewModel.loadMoreNotifications() }
          }
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
      }

      ForEach(viewModel.readNotificationsByDate, id: \.key) { section in
        NotificationSection(
          title: section.key,
          notifications: section.value,
          isUnread: false,
          isLoading: viewModel.isLoadingMore
            && section.key == viewModel.readNotificationsByDate.last?.key,
          onMarkAsRead: { _ in },
          onMarkAllAsRead: {},
          onLoadMore: {
            Task { await viewModel.loadMoreNotifications() }
          }
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
      }
    }
    .listStyle(.plain)
    .animation(.easeInOut(duration: 0.3), value: viewModel.unreadNotifications.count)
    .animation(.easeInOut(duration: 0.3), value: viewModel.readNotificationsByDate.count)
    .refreshable {
      await viewModel.refreshNotifications()
    }
    .environmentObject(feedRefreshManager)
  }
}

struct NotificationsView_Previews: PreviewProvider {
  static var previews: some View {
    NotificationsView()
      .environmentObject(FeedRefreshManager())
      .environmentObject(AuthManager())
  }
}
