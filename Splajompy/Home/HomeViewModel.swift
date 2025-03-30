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
        private var offset = 0
        
        init() {
            loadMorePosts()
        }
        
        func loadMorePosts() {
            Task { @MainActor in
                do {
                    let fetchedPosts: [DetailedPost] = try await APIService.shared.request(endpoint: "/posts/following?limit=\(fetchLimit)&offset=\(offset)")
                    self.posts.append(contentsOf: fetchedPosts)
                    offset += fetchLimit
                }
            }
        }
        
        func refreshPosts() {
            Task { @MainActor in
                offset = 0
                self.posts = []
                loadMorePosts()
            }
        }
        
        func toggleLike(on post: DetailedPost) {
            print("toggling like on post \(post.Post.PostID)")
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
