import SwiftUI

struct StatRow: View {
  let label: String
  let value: Int

  var body: some View {
    HStack {
      Text(label)
        .foregroundStyle(.primary)
      Spacer()
      Text("\(value)")
        .fontWeight(.semibold)
        .foregroundStyle(.secondary)
    }
  }
}

struct StatisticsView: View {
  @State private var viewModel: ViewModel

  init(viewModel: ViewModel = ViewModel()) {
    self.viewModel = viewModel
  }

  var body: some View {
    List {
      if case .loaded(let stats) = viewModel.state {
        StatRow(label: "Posts", value: stats.totalPosts)
        StatRow(label: "Comments", value: stats.totalComments)
        StatRow(label: "Likes", value: stats.totalLikes)
        StatRow(label: "Follows", value: stats.totalFollows)
        StatRow(label: "Users", value: stats.totalUsers)
        StatRow(label: "Notifications", value: stats.totalNotifications)
      }
    }
    .overlay {
      switch viewModel.state {
      case .idle, .loading:
        ProgressView()
      case .failed(let error):
        ErrorScreen(
          errorString: error.localizedDescription,
          source: "StatisticsView",
          onRetry: { await viewModel.load() }
        )
      case .loaded:
        EmptyView()
      }
    }
    .modify {
      #if os(iOS)
        $0.pageTitle("Statistics")
      #endif
    }
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
