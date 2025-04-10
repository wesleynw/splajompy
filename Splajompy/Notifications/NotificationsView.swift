import SwiftUI

struct NotificationsView: View {
  @StateObject private var viewModel: ViewModel

  init(viewModel: ViewModel = ViewModel()) {
    _viewModel = StateObject(wrappedValue: viewModel)
  }

  var body: some View {
    NavigationStack {
      ZStack {
        switch viewModel.state {
        case .idle:
          Color.clear
          
        case .loading:
          ProgressView()
            .controlSize(.large)
          
        case .loaded(let notifications):
          if notifications.isEmpty {
            Text("No notifications.")
              .font(.title3)
              .fontWeight(.bold)
          } else {
            List {
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
              }
            }
            .listStyle(.plain)
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
                  await viewModel.loadNotifications()
                }
              }
              .padding()
          }
        }
      }
      .task {
        await viewModel.loadNotifications()
      }
      .toolbar {
        Button {
          viewModel.markAllNotificationsAsRead()
        } label: {
          Image(systemName: "checklist.checked")
        }
      }
      .navigationTitle("Notifications")
    }
  }
}

struct NotificationRow: View {
  let notification: Notification
  
  let formatter = RelativeDateTimeFormatter()

  private var notificationDate: Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.date(from: notification.createdAt) ?? Date()
  }

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text(notification.message)
          .font(.body)
          .fontWeight(notification.viewed ? .regular : .semibold)

        //                Text(formattedDate(notification.createdAt))
        //                    .font(.caption)
        //                    .foregroundColor(.secondary)
        Text(formatter.localizedString(for: notificationDate, relativeTo: Date()))
          .font(.caption)
          .foregroundColor(.gray)
      }

      Spacer()

      if !notification.viewed {
        Circle()
          .fill(Color.blue)
          .frame(width: 10, height: 10)
      }
    }
    .padding(.vertical, 4)
  }

  private func formattedDate(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .full
    return formatter.localizedString(for: date, relativeTo: Date())
  }
}

struct NotificationsView_Previews: PreviewProvider {
  static var previews: some View {
    Group {
      NotificationsView(viewModel: createViewModel(state: .loaded))
        .previewDisplayName("Loaded State")

      NotificationsView(viewModel: createViewModel(state: .empty))
        .previewDisplayName("Empty State")

      NotificationsView(viewModel: createViewModel(state: .loading))
        .previewDisplayName("Loading State")

      NotificationsView(viewModel: createViewModel(state: .error))
        .previewDisplayName("Error State")
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
