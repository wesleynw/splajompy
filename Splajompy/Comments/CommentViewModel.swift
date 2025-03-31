//
//  ViewModel-PostView.swift
//  Splajompy
//
//  Created by Wesley Weisenberger on 3/25/25.
//

import Foundation

extension CommentsView {
    class ViewModel: ObservableObject {
        private let postID: Int
        
        @Published var comments = [Comment]()
        @Published var isLoading = true
        
        init(postID: Int) {
            self.postID = postID
            loadComments()
        }
        
        func loadComments() {
            Task { @MainActor in
                isLoading = true
                do {
                    comments = try await APIService.shared.request(endpoint: "/post/\(postID)/comments", method: "GET")
                } catch {
                    print("error fetching comments: \(error.localizedDescription)")
                }
                isLoading = false
            }
        }
        
        func toggleLike(for comment: Comment) {
            Task {
                @MainActor in
                let method = comment.IsLiked ? "DELETE" : "POST"
                
                do {
                    try await APIService.shared.requestWithoutResponse(endpoint: "/post/\(comment.PostID)/comment/\(comment.CommentID)/liked", method: method)
                } catch {
                    print("error adding like to post: \(error.localizedDescription)")
                }
                if let index = comments.firstIndex(where: { $0.CommentID == comment.CommentID }) {
                    comments[index].IsLiked.toggle()
                }
                // TODO: update parent viewModel with comment count
            }
        }
        
        func addComment(text: String) {
            Task { @MainActor in
                do {
                    let newComment: Comment = try await APIService.shared.request(endpoint: "/post/\(postID)/comment", method: "POST", body: ["Text": text])
                    comments.append(newComment)
                    // TODO: update comment count in parent VM
                } catch {
                    print("Error adding like to post: \(error.localizedDescription)")
                }
            }
        }
    }
}
