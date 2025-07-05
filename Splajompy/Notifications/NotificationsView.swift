import SwiftUI

struct NotificationsView: View {
  @StateObject private var viewModel = ViewModel()
  @EnvironmentObject private var authManager: AuthManager

  var body: some View {
    Group {
      switch viewModel.state {
      case .idle, .loading:
        loadingView
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

  private func notificationsSectionedList(
    sections: [NotificationDateSection: [Notification]],
    unreadNotifications: [Notification]
  ) -> some View {
    List {
      if !unreadNotifications.isEmpty {
        Section {
          ForEach(unreadNotifications, id: \.notificationId) { notification in
            NotificationRow(notification: notification)
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
              }
              .tint(.blue)
          }
        } header: {
          HStack {
            Text("Unread")

            Spacer()

            Button("Mark All Read") {
              Task {
                await viewModel.markAllNotificationsAsRead()
              }
            }
            .font(.caption)
            .foregroundColor(.blue)
            .buttonStyle(BorderlessButtonStyle())
          }
        }
      }

      ForEach(NotificationDateSection.allCases, id: \.self) { section in
        if let notifications = sections[section], !notifications.isEmpty {
          Section(header: Text(section.rawValue)) {
            ForEach(notifications, id: \.notificationId) { notification in
              NotificationRow(notification: notification)
                .onAppear {
                  let shouldLoadMore =
                    notifications.count < 8
                    || (notifications.count >= 8
                      && notification.notificationId
                        == notifications[notifications.count - 8].notificationId)

                  if shouldLoadMore {
                    Task {
                      await viewModel.loadMoreNotifications()
                    }
                  }
                }
            }
          }
          .onAppear {
            var lastSectionWithNotifications: NotificationDateSection? = nil
            for sectionCase in NotificationDateSection.allCases.reversed() {
              if let sectionNotifications = sections[sectionCase],
                !sectionNotifications.isEmpty
              {
                lastSectionWithNotifications = sectionCase
                break
              }
            }

            if section == lastSectionWithNotifications {
              Task {
                await viewModel.loadMoreNotifications()
              }
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
    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
    .refreshable {
      await viewModel.refreshNotifications()
    }
  }
}

#Preview {
  NotificationsView()
    .environmentObject(AuthManager())
}
