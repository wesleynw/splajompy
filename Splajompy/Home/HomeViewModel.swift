//
//  HomeViewModel.swift
//  Splajompy
//
//  Created by Wesley Weisenberger on 3/24/25.
//

import Foundation

let fetchLimit = 10

extension HomeView {
    class ViewModel: ObservableObject {
        private let postService = PostService()
        @Published var posts = [DetailedPost]()
        @Published var isLoading = true
        @Published var error = ""
        private var offset = 0
        
        init() {
            loadMorePosts()
        }
        
        func loadMorePosts(reset: Bool = false) {
            isLoading = true
            Task { @MainActor in
                do {
                    let fetchedPosts: [DetailedPost] = try await APIService.shared.request(endpoint: "/posts/following?limit=\(fetchLimit)&offset=\(offset)")
                    if reset {
                        self.posts = fetchedPosts
                    } else {
                        self.posts.append(contentsOf: fetchedPosts)
                    }
                    offset += fetchLimit
                    error = ""
                } catch {
                    print("error fetching posts: \(error.localizedDescription)")
                    self.error = error.localizedDescription
                }
            }
            isLoading = false
        }
        
        func refreshPosts() {
            isLoading = true
            Task { @MainActor in
                offset = 0
                loadMorePosts(reset: true)
            }
            isLoading = false
        }
        
        func toggleLike(on post: DetailedPost) {
            Task {
                @MainActor in
                if let index = posts.firstIndex(where: { $0.Post.PostID == post.Post.PostID }) {
                    posts[index].IsLiked.toggle()
                    await postService.toggleLike(for: post)
                }
            }
        }
    }
}
