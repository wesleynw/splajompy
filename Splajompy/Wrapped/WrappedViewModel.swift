import Foundation

struct WrappedData: Decodable {
  let activityData: ActivityOverviewData
  let weeklyActivityData: [Int]
  let sliceData: SliceData
  let comparativePostStatisticsData: ComparativePostStatisticsData
  let mostLikedPost: DetailedPost
  let favoriteUsers: [FavoriteUserData]
  let totalWordCount: Int
  let controversialPoll: Poll?
  let generatedUtc: Date
}

struct ActivityOverviewData: Decodable {
  let activityCountCeiling: Int
  let counts: [String: Int]
  let mostActiveDay: String
}

struct SliceData: Decodable {
  let percent: Double
  let postComponent: Double
  let commentComponent: Double
  let likeComponent: Double
}

struct ComparativePostStatisticsData: Decodable {
  let postLengthVariation: Double
  let imageLengthVariation: Double
}

struct FavoriteUserData: Decodable {
  let user: PublicUser
  let proportion: Double
}

enum WrappedState {
  case idle
  case loading
  case loaded(WrappedData)
  case failed(String)

  var isLoading: Bool {
    if case .loading = self {
      return true
    }
    return false
  }
}

@MainActor class WrappedViewModel: ObservableObject {
  @Published var state: WrappedState = .idle

  func load() async {
    if case .loaded(_) = state {
      return
    }

    state = .loading

    let result: AsyncResult<WrappedData> =
      await APIService.performRequest(endpoint: "wrapped")

    switch result {
    case .success(let data):
      state = .loaded(data)
    case .error(let error):
      state = .failed(error.localizedDescription)
    }
  }
}
