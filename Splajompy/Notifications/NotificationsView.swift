import SwiftUI

struct NotificationsView: View {
  @StateObject private var viewModel: ViewModel
  @EnvironmentObject private var authManager: AuthManager
  @State private var refreshId = UUID()

  init(viewModel: ViewModel = ViewModel()) {
    self._viewModel = StateObject(wrappedValue: viewModel)
  }

  var body: some View {
    Group {
      switch viewModel.state {
      case .idle, .loading:
        ProgressView()
      case .loaded(let sections, let unreadNotifications):
        if sections.isEmpty && unreadNotifications.isEmpty {
          noNotificationsView
        } else {
          notificationsSectionedList(
            sections: sections,
            unreadNotifications: unreadNotifications
          )
        }
      case .failed(let error):
        ErrorScreen(
          errorString: error.localizedDescription,
          onRetry: { await viewModel.refreshNotifications() }
        )
      }
    }
    #if os(macOS)
      .frame(maxWidth: .infinity)
    #endif
    .onAppear {
      if case .idle = viewModel.state {
        Task { await viewModel.refreshNotifications() }
      }
    }
    .navigationTitle("Notifications")
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
    List {
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

            Spacer()

            Button("Mark All Read") {
              viewModel.markAllNotificationsAsRead()
            }
            .font(.caption)
            .foregroundColor(.blue)
            .padding(5)
          }
        }
      }

      if !viewModel.hasMoreUnreadToLoad {
        ForEach(NotificationDateSection.allCases, id: \.self) { section in
          if let notifications = sections[section], !notifications.isEmpty {
            Section(header: Text(section.rawValue)) {
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
                  var lastSectionWithNotifications: NotificationDateSection? =
                    nil
                  for sectionCase in NotificationDateSection.allCases.reversed() {
                    if let sectionNotifications = sections[sectionCase],
                      !sectionNotifications.isEmpty
                    {
                      lastSectionWithNotifications = sectionCase
                      break
                    }
                  }

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
            .scaleEffect(1.1)
            .padding()
          Spacer()
        }
        .id(UUID())
      }
    }
    .frame(maxWidth: .infinity)
    .listStyle(.plain)
    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
    .refreshable {
      await viewModel.refreshNotifications()
      refreshId = UUID()
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
