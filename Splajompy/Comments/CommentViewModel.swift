//
//  ViewModel-PostView.swift
//  Splajompy
//
//  Created by Wesley Weisenberger on 3/25/25.
//

import Foundation

extension CommentsView {
    class ViewModel: ObservableObject {
        private let postId: Int
        private let commentService = CommentService()
        
        @Published var comments = [Comment]()
        
        init(postId: Int) {
            self.postId = postId
            loadComments()
        }
        
        func loadComments() {
            Task {
                @MainActor in
                let fetchedComments = await commentService.fetchCommentsByPostId(postId: self.postId)
                print("fetched comments: ", fetchedComments)
                self.comments = fetchedComments
            }
        }
        
        func toggleLike(for comment: Comment) {
            Task {
                @MainActor in
                await commentService.toggleLike(for: comment)
                if let index = comments.firstIndex(where: { $0.CommentID == comment.CommentID }) {
                    comments[index].IsLiked.toggle()
                }
            }
        }
    }
}
