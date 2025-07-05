import SwiftUI

struct NotificationsView: View {
  @StateObject private var viewModel = ViewModel()
  @EnvironmentObject private var authManager: AuthManager

  var body: some View {
    Group {
      switch viewModel.state {
      case .idle, .loading:
        loadingView
      case .loaded(let notifications):
        if notifications.isEmpty {
          noNotificationsView
        } else {
          notificationsList(notifications: notifications)
        }
      case .failed(let error):
        ErrorScreen(
          errorString: error.localizedDescription,
          onRetry: { await viewModel.refreshNotifications() }
        )
      }
    }
    .onAppear {
      if case .idle = viewModel.state {
        Task { await viewModel.refreshNotifications() }
      }
    }
    .navigationTitle("Notifications")
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

  private var noNotificationsView: some View {
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

  private func notificationsList(notifications: [Notification]) -> some View {
    List {
      ForEach(notifications, id: \.notificationId) { notification in
        NotificationRow(notification: notification)
          .onAppear {
            if notifications.count < 10
              || notification.notificationId
                == notifications[notifications.endIndex - 8].notificationId
            {
              Task {
                await viewModel.loadMoreNotifications()
              }
            }
          }
      }

      if viewModel.isFetching {
        HStack {
          Spacer()
          ProgressView()
            .id(UUID())  // a fix from: https://stackoverflow.com/questions/70627642/progressview-hides-on-list-scroll/75431883#75431883
            .scaleEffect(1.1)
            .padding()
          Spacer()
        }
      }
    }
    .listStyle(.plain)
    .refreshable {
      await viewModel.refreshNotifications()
    }
  }
}

#Preview {
  NotificationsView()
    .environmentObject(AuthManager())
}
