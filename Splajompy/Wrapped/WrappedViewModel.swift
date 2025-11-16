import Foundation

struct ActivityOverviewData: Decodable, Equatable {
  let activityCountCeiling: Int
  let counts: [String: Int]
  let mostActiveDay: String
}

enum WrappedState: Equatable {
  case idle
  case loading
  case loaded(ActivityOverviewData)
  case failed(String)
}

@MainActor class WrappedViewModel: ObservableObject {
  @Published var state: WrappedState = .idle

  func load() async {
    if case .loaded(_) = state {
      return
    }

    state = .loading

    let result: AsyncResult<ActivityOverviewData> =
      await APIService.performRequest(endpoint: "wrapped")

    switch result {
    case .success(let data):
      state = .loaded(data)
    case .error(let error):
      state = .failed(error.localizedDescription)
    }
  }
}
