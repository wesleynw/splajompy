import Foundation

enum SearchState {
  case idle
  case loading
  case error(Error)
  case loaded([PublicUser])
}

extension SearchView {
  @MainActor @Observable class ViewModel {
    var state: SearchState = .idle

    private let profileService: ProfileServiceProtocol

    init(profileService: ProfileServiceProtocol = ProfileService()) {
      self.profileService = profileService
    }

    func searchUsers(prefix: String) async {
      guard !prefix.isEmpty else {
        clearResults()
        return
      }

      state = .loading

      let result = await profileService.getUserFromUsernamePrefix(
        prefix: prefix
      )

      switch result {
      case .success(let users):
        state = .loaded(users)
      case .error(let error):
        state = .error(error)

      }
    }

    func clearResults() {
      state = .idle
    }
  }
}
