//
//  ProfileViewModel.swift
//  Splajompy
//
//  Created by Wesley Weisenberger on 3/29/25.
//

import Foundation

struct UserProfile: Decodable {
  let userId: Int
  let email: String
  let username: String
  let createdAt: String
  let name: String
  let bio: String
  let isFollower: Bool
  let isFollowing: Bool
}

extension ProfileView {
  class ViewModel: ObservableObject {
    private let userId: Int
    private var offset = 0

    @Published var profile: UserProfile?
    @Published var posts = [DetailedPost]()
    @Published var postError = ""
    @Published var isLoadingProfile = true

    init(userId: Int) {
      self.userId = userId
      loadProfile()
    }

    func loadProfile() {
      isLoadingProfile = true

      Task { @MainActor in
        do {
          profile = try await APIService.shared.request(endpoint: "/user/\(userId)")
        } catch {
          print("error fetching user profile: \(error.localizedDescription)")
        }
        isLoadingProfile = false
      }

    }
  }
}
