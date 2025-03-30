//
//  ProfileViewModel.swift
//  Splajompy
//
//  Created by Wesley Weisenberger on 3/29/25.
//

import Foundation

struct UserProfile: Decodable {
    let UserID: Int
    let Email: String
    let Username: String
    let CreatedAt: String
    let Name: String?
    let Bio: String?
    let IsFollower: Bool
    let IsFollowing: Bool
}

extension ProfileView {
    class ViewModel: ObservableObject {
        private let userID: Int
        private var offset = 0
        
        @Published var profile: UserProfile?
        @Published var posts = [DetailedPost]()
        @Published var postError = ""
        @Published var isLoadingPosts = true
        @Published var isLoadingProfile = true
        
        init(userID: Int) {
            self.userID = userID
            loadProfile()
            loadProfilePosts()
        }
        
        func loadProfile() {
            isLoadingProfile = true
            
            Task { @MainActor in
                do {
                    profile = try await APIService.shared.request(endpoint: "/user/\(userID)")
                } catch {
                    print("error fetching user profile: \(error.localizedDescription)")
                }
                isLoadingProfile = false
            }
            
        }
        
        func loadProfilePosts() {
            isLoadingPosts = true
            
            Task { @MainActor in
                do {
                    let fetchedPosts: [DetailedPost] = try await APIService.shared.request(endpoint: "/user/\(userID)/posts?limit=\(fetchLimit)&offset=\(offset)")
                    self.posts.append(contentsOf: fetchedPosts)
                    offset += fetchLimit
                } catch {
                    postError = error.localizedDescription
                }
                isLoadingPosts = false
            }
        }
    }
}
