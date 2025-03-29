//
//  CommentService.swift
//  Splajompy
//
//  Created by Wesley Weisenberger on 3/25/25.
//

// TODO: i think i've disrespected how MVVM works by conflating how I'm using Services and ViewModels. Ideally I think Service=Model. anyway...

struct Comment: Decodable {
    let CommentID: Int
    let PostID: Int
    let UserID: Int
    let Text: String
    let CreatedAt: String
    let User: User
    var IsLiked: Bool
}

class CommentService {
    func fetchCommentsByPostId(postId: Int) async -> [Comment] {
        do {
            return try await APIService.shared.request(endpoint: "/post/\(postId)/comments", method: "GET")
        } catch {
            print("error fetching comments: \(error.localizedDescription)")
            return []
        }
    }
    
    func toggleLike(for comment: Comment) async -> Void {
        let method = comment.IsLiked ? "DELETE" : "POST"
        
        do {
            try await APIService.shared.requestWithoutResponse(endpoint: "/post/\(comment.PostID)/comment/\(comment.CommentID)/liked", method: method)
        } catch {
            print("error adding like to post: \(error.localizedDescription)")
        }
    }
}
