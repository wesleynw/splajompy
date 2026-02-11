import PostHog
import SwiftUI

struct NotificationsView: View {
  @State private var viewModel: ViewModel
  @Environment(AuthManager.self) private var authManager
  @State private var refreshId = UUID()
  @State private var scrollOffset = CGFloat.zero

  init(viewModel: ViewModel = ViewModel()) {
    self._viewModel = State(wrappedValue: viewModel)
  }

  var body: some View {
    Group {
      switch viewModel.state {
      case .idle, .loading:
        ProgressView()
          .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    #if os(macOS)
      .frame(maxWidth: .infinity)
      .toolbar(removing: .title)
    #endif
    .onAppear {
      if case .idle = viewModel.state {
        Task { await viewModel.refreshNotifications() }
      }
    }
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        NotificationFilterMenu(filter: $viewModel.selectedFilter)
      }
    }
    .toolbar {
      if #available(iOS 26, macOS 26, *) {
        #if os(iOS)
          ToolbarItem(placement: .topBarLeading) {
            Text("Notifications")
              .fontWeight(.black)
              .font(.title2)
              .fixedSize()
          }
          .sharedBackgroundVisibility(.hidden)
        #else
          ToolbarItem(placement: .principal) {
            Text("Notifications")
              .fontWeight(.black)
              .font(.title2)
              .fixedSize()
          }
          .sharedBackgroundVisibility(.hidden)
        #endif
      } else {
        #if os(iOS)
          ToolbarItem(placement: .topBarLeading) {
            Text("Notifications")
              .fontWeight(.black)
              .font(.title2)
              .fixedSize()
          }
        #else
          ToolbarItem(placement: .principal) {
            Text("Notifications")
              .fontWeight(.black)
              .font(.title2)
              .fixedSize()
          }
        #endif
      }
    }
    .modify {
      if #available(iOS 26, *),
        PostHogSDK.shared.isFeatureEnabled("toolbar-scroll-effect")
      {
        $0.scrollFadeBackground(scrollOffset: scrollOffset)
      }
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
                  for sectionCase in NotificationDateSection.allCases
                    .reversed()
                  {
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
            .padding()
          Spacer()
        }
        .id(UUID())
        .listRowSeparator(.hidden)
      }
    }
    .frame(maxWidth: .infinity)
    .listStyle(.plain)
    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
    .refreshable {
      await viewModel.refreshNotifications()
      refreshId = UUID()
    }
    .modify {
      if #available(iOS 26, *),
        PostHogSDK.shared.isFeatureEnabled("toolbar-scroll-effect")
      {
        $0.scrollFadeEffect(scrollOffset: $scrollOffset)
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
  }
}
