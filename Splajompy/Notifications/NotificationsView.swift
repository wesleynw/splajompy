import Kingfisher
import SwiftUI

struct NotificationsView: View {
  @StateObject private var viewModel = NotificationsViewModel()

  @EnvironmentObject private var authManager: AuthManager
  @EnvironmentObject private var feedRefreshManager: FeedRefreshManager


  var body: some View {
    ZStack {
      if viewModel.isInitialLoading {
        ProgressView()
          .scaleEffect(1.5)
          .frame(maxWidth: .infinity)
          .frame(maxHeight: .infinity)
      } else if viewModel.unreadNotifications.isEmpty && viewModel.readNotifications.isEmpty {
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
      } else {
        NotificationSectionsView(viewModel: viewModel)
          .environmentObject(feedRefreshManager)
      }
    }
    .navigationTitle("Notifications")
    .environmentObject(authManager)
    .environmentObject(feedRefreshManager)
    .onAppear {
      if viewModel.unreadNotifications.isEmpty && viewModel.readNotifications.isEmpty {
        Task { await viewModel.refreshNotifications() }
      }
    }
  }
}

struct NotificationsView_Previews: PreviewProvider {
  static var previews: some View {
    NotificationsView()
      .environmentObject(FeedRefreshManager())
      .environmentObject(AuthManager())
  }
}
