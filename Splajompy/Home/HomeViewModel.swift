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
        @Published var posts = [Post]()
        private var offset = 0
        
        init() {
            loadMorePosts()
        }
        
        func loadMorePosts() {
            Task { @MainActor in
                let fetchedPosts = await postService.fetchPostsByFollowing(offset: offset, limit: fetchLimit)
                self.posts.append(contentsOf: fetchedPosts)
                offset += fetchLimit
            }
        }
        
        func refreshPosts() {
            Task { @MainActor in
                offset = 0
                let fetchedPosts = await postService.fetchPostsByFollowing(offset: offset, limit: fetchLimit)
                self.posts = fetchedPosts
                loadMorePosts()
            }
        }
        
        func toggleLike(on post: Post) {
            print("toggling like on post \(post.PostID)")
            Task {
                @MainActor in
                if let index = posts.firstIndex(where: { $0.PostID == post.PostID }) {
                    posts[index].Liked.toggle()
                    await postService.toggleLike(for: post)
                }
            }
        }
    }
}
