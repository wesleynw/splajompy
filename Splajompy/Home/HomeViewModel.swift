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
                if let index = posts.firstIndex(where: { $0.Post.PostID == post.Post.PostID }) {
                    posts[index].IsLiked.toggle()
                    let method = post.IsLiked ? "DELETE" : "POST"
                            
                    do {
                        try await APIService.shared.requestWithoutResponse(endpoint: "/post/\(post.Post.PostID)/liked", method: method)
                    } catch {
                        print("Error adding like to post: \(error.localizedDescription)")
                    }
                }
            }
        }
        
        func addComment(on post: DetailedPost, content: String) {
            Task { @MainActor in
                if let index = posts.firstIndex(where: { $0.Post.PostID == post.Post.PostID }) {
                    posts[index].CommentCount += 1
                            
                    do {
                        
                        try await APIService.shared.requestWithoutResponse(endpoint: "/post/\(post.Post.PostID)/comment", method: "POST", body: ["Text": content])
                    } catch {
                        print("Error adding like to post: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}
