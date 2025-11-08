import Foundation

extension SearchView {
  @MainActor
  class ViewModel: ObservableObject {
    @Published private(set) var searchResults: [PublicUser] = []
    @Published private(set) var isLoading = false

    private let profileService: ProfileServiceProtocol

    init(profileService: ProfileServiceProtocol = ProfileService()) {
      self.profileService = profileService
    }

    func searchUsers(prefix: String) {
      guard !prefix.isEmpty else {
        clearResults()
        return
      }

      isLoading = true

      Task {
        let result = await profileService.getUserFromUsernamePrefix(prefix: prefix)

        switch result {
        case .success(let users):
          searchResults = users
        case .error:
          searchResults = []
        }

        isLoading = false
      }
    }

    func clearResults() {
      searchResults = []
      isLoading = false
    }
  }
}
