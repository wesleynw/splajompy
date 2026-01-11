import SwiftUI

struct StatRow: View {
  let label: String
  let value: Int

  var body: some View {
    HStack {
      Text(label)
        .foregroundColor(.primary)
      Spacer()
      Text("\(value)")
        .fontWeight(.semibold)
        .foregroundColor(.secondary)
    }
  }
}

struct StatisticsView: View {
  @State private var viewModel: ViewModel

  init(viewModel: ViewModel = ViewModel()) {
    self.viewModel = viewModel
  }

  var body: some View {
    Group {
      switch viewModel.state {
      case .idle, .loading:
        ProgressView()
      case .loaded(let stats):
        List {
          StatRow(label: "Posts", value: stats.totalPosts)
          StatRow(label: "Comments", value: stats.totalComments)
          StatRow(label: "Likes", value: stats.totalLikes)
          StatRow(label: "Follows", value: stats.totalFollows)
          StatRow(label: "Users", value: stats.totalUsers)
          StatRow(label: "Notifications", value: stats.totalNotifications)
        }
      case .failed(let error):
        ErrorScreen(
          errorString: error.localizedDescription,
          onRetry: { await viewModel.load() }
        )
      }
    }
    .navigationTitle("Statistics")
    #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
    #endif
    .refreshable {
      await viewModel.load(showLoadingState: false)
    }
    .task {
      await viewModel.load()
    }
  }
}

#Preview {
  let viewModel: StatisticsView.ViewModel =
    StatisticsView.ViewModel(profileService: MockProfileService())

  NavigationStack {
    StatisticsView(viewModel: viewModel)
  }
}
