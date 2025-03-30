//
//  models.swift
//  Splajompy
//
//  Created by Wesley Weisenberger on 3/28/25.
//

struct User: Decodable {
    let UserID: Int
    let Email: String
    let Username: String
    let CreatedAt: String
    let Name: String?
}

struct Comment: Decodable {
    let CommentID: Int
    let PostID: Int
    let UserID: Int
    let Text: String
    let CreatedAt: String
    let User: User
    var IsLiked: Bool
}

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
    var CommentCount: Int
    var Images: [ImageDTO]?
    
    var id: Int { Post.PostID }
    
    static func == (lhs: DetailedPost, rhs: DetailedPost) -> Bool {
        return lhs.Post.PostID == rhs.Post.PostID
    }
}
