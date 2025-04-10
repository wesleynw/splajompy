import SwiftUI

struct NotificationsView: View {
  @StateObject private var viewModel = ViewModel()

  var body: some View {
    ZStack {
      switch viewModel.state {
      case .idle:
        Color.clear  // Or some initial state UI

      case .loading:
        ProgressView()

      case .loaded(let notifications):
        if notifications.isEmpty {
          Text("No notifications")
        } else {
          List {
            ForEach(notifications) { notification in
              NotificationRow(notification: notification)
                .onTapGesture {
                  print("mark as read")
                }
            }
          }
        }

      case .failed(let error):
        VStack {
          Text("Something went wrong")
          Text(error.localizedDescription)
            .font(.caption)
            .foregroundColor(.red)
          Button("Try Again") {
            Task { @MainActor in
              await viewModel.loadNotifications()
            }
          }
        }
      }
    }
    .task {
      await viewModel.loadNotifications()
    }
  }
}

struct NotificationRow: View {
    let notification: Notification
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.message)
                    .font(.body)
                    .fontWeight(notification.viewed ? .regular : .semibold)
                
//                Text(formattedDate(notification.createdAt))
//                    .font(.caption)
//                    .foregroundColor(.secondary)
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
