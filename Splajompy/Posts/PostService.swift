//
//  PostService.swift
//  Splajompy
//
//  Created by Wesley Weisenberger on 3/24/25.
//

import Foundation

struct ImageDTO: Decodable {
    let ImageID: Int
    let PostID: Int
    let Height: Int
    let Width: Int
    let ImageBlobUrl: String
    let DisplayOrder: Int
}

struct Post: Decodable {
    let PostID: Int
    let UserID: Int
    let Text: String?
    let CreatedAt: String
}

struct DetailedPost: Decodable, Equatable, Identifiable {
    let Post: Post
    let User: User
    var IsLiked: Bool
    let CommentCount: Int
    var Images: [ImageDTO]?
    
    var id: Int { Post.PostID }
    
    static func == (lhs: DetailedPost, rhs: DetailedPost) -> Bool {
        return lhs.Post.PostID == rhs.Post.PostID
    }
}

class PostService {
    func fetchPostsByFollowing(offset: Int, limit: Int) async -> [Post] {
        do {
            return try await APIService.shared.request(endpoint: "/posts/following?offset=\(offset)&limit=\(limit)", method: "GET")
        } catch {
            print("error: \(error.localizedDescription)")
            return []
        }
    }
    
    func toggleLike(for post: DetailedPost) async -> Void {
        let method = post.IsLiked ? "DELETE" : "POST"
                
        do {
            try await APIService.shared.requestWithoutResponse(endpoint: "/post/\(post.Post.PostID)/liked", method: method)
        } catch {
            print("Error adding like to post: \(error.localizedDescription)")
        }
    }
}
