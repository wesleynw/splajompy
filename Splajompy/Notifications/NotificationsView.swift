import SwiftUI

struct NotificationsView: View {
  @State private var viewModel: ViewModel

  init(viewModel: ViewModel = ViewModel()) {
    self._viewModel = State(wrappedValue: viewModel)
  }

  var body: some View {
    ScrollView {
      LazyVStack {
        NotificationBreadcrumbFilter(filter: $viewModel.selectedFilter)
          .frame(maxWidth: .infinity, alignment: .leading)
          .contentMargins(.leading, 10, for: .scrollContent)
          .listRowInsets(EdgeInsets())

        if case .loaded(let sections, let unreadNotifications) = viewModel
          .state,
          !sections.isEmpty || !unreadNotifications.isEmpty
        {
          notificationsList(
            sections: sections,
            unreadNotifications: unreadNotifications
          )
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
      case .loaded(let sections, let unreadNotifications)
      where sections.isEmpty && unreadNotifications.isEmpty:
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
    sections: [NotificationDateSection: [Notification]],
    unreadNotifications: [Notification]
  ) -> some View {
    if !unreadNotifications.isEmpty {
      Section {
        ForEach(unreadNotifications, id: \.notificationId) { notification in
          NotificationRow(notification: notification)
            #if os(macOS)
              .frame(maxWidth: 600)
              .frame(maxWidth: .infinity)
            #endif
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
            .onAppear {
              if notification.notificationId
                == unreadNotifications.last?.notificationId
              {
                Task {
                  await viewModel.loadMoreUnreadNotifications()
                }
              }
            }
        }
      } header: {
        HStack {
          Text("New")
            .fontWeight(.semibold)

          Spacer()

          Button(action: {
            viewModel.markAllNotificationsAsRead()
          }) {
            Text("Mark All Read")
              .fontWeight(.semibold)
          }
          .controlSize(.small)
          .buttonStyle(.bordered)
        }
      }
    }

    if !viewModel.hasMoreUnreadToLoad {
      let lastSectionWithNotifications = NotificationDateSection.allCases
        .reversed()
        .first { sections[$0]?.isEmpty == false }

      ForEach(NotificationDateSection.allCases, id: \.self) { section in
        if let notifications = sections[section], !notifications.isEmpty {
          Section(header: Text(section.rawValue).fontWeight(.semibold)) {
            ForEach(notifications, id: \.notificationId) { notification in
              NotificationRow(
                notification: notification
              )
              #if os(macOS)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
              #endif
              .onAppear {
                if section == lastSectionWithNotifications
                  && notification.notificationId
                    == notifications.last?.notificationId
                {
                  Task {
                    await viewModel.loadMoreNotifications()
                  }
                }
              }
            }
          }
        }
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
