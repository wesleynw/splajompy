import SwiftUI

enum StatisticsState {
  case idle
  case loading
  case loaded(AppStatistics)
  case failed(Error)
}

extension StatisticsView {
  @MainActor @Observable class ViewModel {
    var state: StatisticsState = .idle
    let profileService: ProfileServiceProtocol

    init(profileService: ProfileServiceProtocol = ProfileService()) {
      self.profileService = profileService
    }

    func load(showLoadingState: Bool = false) async {
      if showLoadingState {
        state = .loading
      }

      let result = await profileService.getAppStatistics()

      switch result {
      case .success(let stats):
        state = .loaded(stats)
      case .error(let error):
        state = .failed(error)
      }
    }
  }
}
