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

struct Post: Decodable, Equatable, Identifiable {
    let PostID: Int
    let Text: String?
    let CreatedAt: String
    let UserID: Int
    let Username: String
    let Name: String?
    let Commentcount: Int
    var Liked: Bool
    var Images: [ImageDTO]?
    
    var id: Int { PostID }
    
    static func == (lhs: Post, rhs: Post) -> Bool {
        return lhs.PostID == rhs.PostID
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
    
    func toggleLike(for post: Post) async -> Void {
        let method = post.Liked ? "DELETE" : "POST"
                
        do {
            try await APIService.shared.requestWithoutResponse(endpoint: "/post/\(post.PostID)/liked", method: method)
        } catch {
            print("Error adding like to post: \(error.localizedDescription)")
        }
    }
}
