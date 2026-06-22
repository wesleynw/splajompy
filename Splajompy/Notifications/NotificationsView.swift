import SwiftUI

struct NotificationsView: View {
  @State private var viewModel: ViewModel

  init(viewModel: ViewModel = ViewModel()) {
    self._viewModel = State(wrappedValue: viewModel)
  }

  var body: some View {
    ScrollView {
      LazyVStack(spacing: 0) {
        NotificationBreadcrumbFilter(filter: $viewModel.selectedFilter)
          .frame(maxWidth: .infinity, alignment: .leading)
          .contentMargins(.leading, 10, for: .scrollContent)

        if case .loaded(let notifications) = viewModel
          .state,
          !notifications.isEmpty
        {
          notificationsList(
            notifications: notifications
          )
          .padding(.horizontal)
          .task {
            if viewModel.lastRefreshTime.addingTimeInterval(5) > Date() {
              do {
                try await Task.sleep(for: .seconds(2))
                viewModel.markAllNotificationsAsRead()
              } catch {}
            }
          }
        }
      }
    }
    .overlay {
      switch viewModel.state {
      case .idle, .loading:
        ProgressView()
          #if os(macOS)
            .controlSize(.small)
          #endif
      case .loaded(let notifications)
      where notifications.isEmpty:
        noNotificationsView
      case .failed(let error):
        ErrorScreen(
          errorString: error.localizedDescription,
          source: "NotificationsView",
          onRetry: { await viewModel.refreshNotifications() }
        )
      default:
        EmptyView()
      }
    }
    .refreshable {
      await viewModel.refreshNotifications()
    }
    .task {
      if case .idle = viewModel.state {
        await viewModel.refreshNotifications()
      }
    }
    #if os(iOS)
      .toolbar {
        if #available(iOS 26, *) {
          ToolbarItem(placement: .topBarLeading) {
            Text("Notifications")
            .fontWeight(.black)
            .font(.title2)
            .fixedSize()
          }
          .sharedBackgroundVisibility(.hidden)
        } else {
          ToolbarItem(placement: .topBarLeading) {
            Text("Notifications")
            .fontWeight(.black)
            .font(.title2)
            .fixedSize()
          }
        }
      }
    #else
      .navigationTitle("Notifications")
    #endif
  }

  private var noNotificationsView: some View {
    VStack {
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
    }
    .frame(maxWidth: .infinity, alignment: .center)
  }

  @ViewBuilder
  private func notificationsList(
    notifications: [Notification]
  ) -> some View {
    ForEach(notifications, id: \.notificationId) { notification in
      NotificationRow(notification: notification)
        #if os(macOS)
          .frame(maxWidth: 600)
          .frame(maxWidth: .infinity, alignment: .center)
        #endif
        .onAppear {
          if notification.notificationId
            == notifications.last?.notificationId
          {
            Task {
              await viewModel.loadMoreNotifications()
            }
          }
        }
        .swipeActions(edge: .leading) {
          Button {
            Task {
              await viewModel.markNotificationAsRead(
                notificationId: notification.notificationId
              )
            }
          } label: {
            Label("Mark as Read", systemImage: "checkmark.circle")
          }
          .tint(.blue)
        }
    }

    if viewModel.hasMoreUnreadToLoad || viewModel.hasMoreToLoad {
      HStack {
        ProgressView()
          .padding()
          #if os(macOS)
            .controlSize(.small)
          #endif
      }
      .frame(maxWidth: .infinity, alignment: .center)
    }
  }
}

#Preview {
  NavigationStack {
    NotificationsView(
      viewModel: NotificationsView.ViewModel(
        notificationService: MockNotificationService()
      )
    )
  }
}
