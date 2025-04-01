//
//  HomeViewModel.swift
//  Splajompy
//
//  Created by Wesley Weisenberger on 3/24/25.
//

import Foundation

let fetchLimit = 10

extension FeedView {
  class ViewModel: ObservableObject {
    var feedType: FeedType
    var userId: Int?

    @Published var posts = [DetailedPost]()
    @Published var isLoading = true
    @Published var error = ""

    private var offset = 0

    init(feedType: FeedType, userId: Int? = nil) {
      self.feedType = feedType
      self.userId = userId
      loadMorePosts()
    }

    func loadMorePosts(reset: Bool = false) {
      isLoading = true
      Task { @MainActor in
        do {
          let urlBase =
            switch feedType {
            case .home:
              "/posts/following"
            case .all:
              "/posts/all"
            case .profile:
              "/user/\(self.userId!)/posts"
            }

          let fetchedPosts: [DetailedPost] = try await APIService.shared.request(
            endpoint: "\(urlBase)?limit=\(fetchLimit)&offset=\(offset)")
          print("fetched posts length: ", fetchedPosts.count)
          if reset {
            self.posts = fetchedPosts
          } else {
            self.posts.append(contentsOf: fetchedPosts)
          }
          offset += fetchLimit
          error = ""
          isLoading = false
        } catch {
          print("error fetching posts: \(error.localizedDescription)")
          self.error = error.localizedDescription
        }
      }
    }

    func refreshPosts() {
      isLoading = true
      Task { @MainActor in
        offset = 0
        loadMorePosts(reset: true)
        isLoading = false
      }
    }

    func toggleLike(on post: DetailedPost) {
      Task { @MainActor in
        if let index = posts.firstIndex(where: { $0.post.postId == post.post.postId }) {
          posts[index].isLiked.toggle()
          let method = post.isLiked ? "DELETE" : "POST"

          do {
            try await APIService.shared.requestWithoutResponse(
              endpoint: "/post/\(post.post.postId)/liked", method: method)
          } catch {
            print("Error adding like to post: \(error.localizedDescription)")
          }
        }
      }
    }

    func addComment(on post: DetailedPost, content: String) {
      Task { @MainActor in
        if let index = posts.firstIndex(where: { $0.post.postId == post.post.postId }) {
          posts[index].commentCount += 1

          do {

            try await APIService.shared.requestWithoutResponse(
              endpoint: "/post/\(post.post.postId)/comment", method: "POST", body: ["Text": content]
            )
          } catch {
            print("Error adding like to post: \(error.localizedDescription)")
          }
        }
      }
    }
  }
}
