import SwiftUI

struct NotificationsView: View {
  @State private var viewModel: ViewModel

  init(viewModel: ViewModel = ViewModel()) {
    self._viewModel = State(wrappedValue: viewModel)
  }

  var body: some View {
    List {
      NotificationBreadcrumbFilter(filter: $viewModel.selectedFilter)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentMargins(.leading, 10, for: .scrollContent)
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)

      if case .loaded(let notifications) = viewModel
        .state,
        !notifications.isEmpty
      {
        notificationsList(
          notifications: notifications
        )
        .task {
          do {
            try await Task.sleep(for: .seconds(2))
            viewModel.markAllNotificationsAsRead()
          } catch {}
        }
      }
    }
    .listStyle(.plain)
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
    .onAppear {
      if case .idle = viewModel.state {
        Task { await viewModel.refreshNotifications() }
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
    let unread = notifications.filter({ !$0.viewed })
    if !unread.isEmpty {
      Section {
        ForEach(unread, id: \.notificationId) { notification in
          NotificationRow(notification: notification)
            .onAppear {
              if notification.notificationId
                == notifications.last?.notificationId
              {
                Task {
                  await viewModel.loadMoreUnreadNotifications()
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
      } header: {
        Text("New")
          .fontWeight(.bold)
      }
    }

    Section {
      ForEach(notifications.filter({ $0.viewed }), id: \.notificationId) {
        notification in
        NotificationRow(notification: notification)
          .onAppear {
            if notification.notificationId
              == notifications.last?.notificationId
            {
              Task {
                await viewModel.loadMoreUnreadNotifications()
              }
            }
          }
      }
    } header: {
      Text("Older")
        .fontWeight(.bold)
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
      .listRowSeparator(.hidden)
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
