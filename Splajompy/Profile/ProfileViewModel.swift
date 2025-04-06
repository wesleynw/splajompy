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
  var isFollowing: Bool
}

extension ProfileView {
  class ViewModel: ObservableObject {
    private let userId: Int
    private var offset = 0

    @Published var profile: UserProfile?
    @Published var posts = [DetailedPost]()
    @Published var postError = ""
    @Published var isLoadingProfile = true
    @Published var isLoadingFollowButton = false

    init(userId: Int) {
      self.userId = userId
      loadProfile()
    }

    func loadProfile() {
      Task { @MainActor in
        isLoadingProfile = true
        do {
          profile = try await APIService.shared.request(
            endpoint: "/user/\(userId)"
          )
        } catch {
          print("error fetching user profile: \(error.localizedDescription)")
        }
        isLoadingProfile = false
      }
    }

    func toggleFollowing() {
      if let profile = self.profile {
        Task { @MainActor in
          isLoadingFollowButton = true
          let method = profile.isFollowing ? "DELETE" : "POST"
          do {
            try await APIService.shared.requestWithoutResponse(
              endpoint: "/follow/\(userId)",
              method: method
            )
          } catch {
            print("error toggling following status: \(error.localizedDescription)")
          }
          isLoadingFollowButton = false
          self.profile?.isFollowing.toggle()
        }
      }
    }
  }
}
