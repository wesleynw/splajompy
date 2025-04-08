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
    @Published var hasMorePosts = true
    @Published var error = ""

    private var isLoadingMore = false

    private var offset = 0

    init(feedType: FeedType, userId: Int? = nil) {
      self.feedType = feedType
      self.userId = userId
      loadMorePosts()
    }

    private var loadMoreTask: Task<Void, Never>? = nil

    func loadMorePosts(reset: Bool = false) {
      guard !isLoadingMore else { return }
      guard reset || hasMorePosts else { return }

      isLoadingMore = true
      isLoading = true

      if reset {
        offset = 0
      }

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

          if reset {
            self.posts = fetchedPosts
          } else {
            self.posts.append(contentsOf: fetchedPosts)
          }

          hasMorePosts = fetchedPosts.count >= fetchLimit
          offset += fetchLimit
          error = ""
        } catch {
          print("Error fetching posts: \(error.localizedDescription)")
          self.error = error.localizedDescription
        }
        isLoading = false
        isLoadingMore = false
      }
    }

    func refreshPosts() {
      Task { @MainActor in
        offset = 0
        loadMorePosts(reset: true)
      }
    }

    func toggleLike(on post: DetailedPost) {
      Task { @MainActor in
        if let index = posts.firstIndex(where: {
          $0.post.postId == post.post.postId
        }) {
          posts[index].isLiked.toggle()
          let method = post.isLiked ? "DELETE" : "POST"

          do {
            try await APIService.shared.requestWithoutResponse(
              endpoint: "/post/\(post.post.postId)/liked",
              method: method
            )
          } catch {
            print("Error adding like to post: \(error.localizedDescription)")
          }
        }
      }
    }

    func addComment(on post: DetailedPost, content: String) {
      Task { @MainActor in
        if let index = posts.firstIndex(where: {
          $0.post.postId == post.post.postId
        }) {
          posts[index].commentCount += 1

          do {
            try await APIService.shared.requestWithoutResponse(
              endpoint: "/post/\(post.post.postId)/comment",
              method: "POST",
              body: ["Text": content]
            )
          } catch {
            print("Error adding like to post: \(error.localizedDescription)")
          }
        }
      }
    }
  }
}
