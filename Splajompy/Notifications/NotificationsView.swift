import SwiftUI

struct NotificationsView: View {
  @State private var viewModel: ViewModel
  @Environment(AuthManager.self) private var authManager
  @State private var refreshId = UUID()
  init(viewModel: ViewModel = ViewModel()) {
    self._viewModel = State(wrappedValue: viewModel)
  }

  var body: some View {
    List {
      Section {
        if case .loaded(let sections, let unreadNotifications) = viewModel.state,
          !sections.isEmpty || !unreadNotifications.isEmpty
        {
          notificationsSectionedList(
            sections: sections,
            unreadNotifications: unreadNotifications
          )
        }
      } header: {
        NotificationBreadcrumbFilter(filter: $viewModel.selectedFilter)
          .frame(maxWidth: .infinity, alignment: .leading)
          .listRowInsets(EdgeInsets())
      }
    }
    .listStyle(.plain)
    .contentMargins(.top, 0, for: .scrollContent)
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
          onRetry: { await viewModel.refreshNotifications() }
        )
      default:
        EmptyView()
      }
    }
    .refreshable {
      await viewModel.refreshNotifications()
      refreshId = UUID()
    }
    #if os(macOS)
      .frame(maxWidth: .infinity)
      .navigationTitle("Notifications")
    #endif
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
    #endif
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

  private func notificationsSectionedList(
    sections: [NotificationDateSection: [Notification]],
    unreadNotifications: [Notification]
  ) -> some View {
    Group {
      if !unreadNotifications.isEmpty {
        Section {
          ForEach(unreadNotifications, id: \.notificationId) { notification in
            NotificationRow(notification: notification, refreshId: refreshId)
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
                  notification: notification,
                  refreshId: refreshId
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

      // the uuid part is a fix from: https://stackoverflow.com/questions/70627642/progressview-hides-on-list-scroll/75431883#75431883
      if viewModel.hasMoreUnreadToLoad || viewModel.hasMoreToLoad {
        HStack {
          Spacer()
          ProgressView()
            .padding()
          Spacer()
        }
        .id(UUID())
        .listRowSeparator(.hidden)
      }
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
    .environment(AuthManager())
  }
}
