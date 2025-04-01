//
//  models.swift
//  Splajompy
//
//  Created by Wesley Weisenberger on 3/28/25.
//

struct User: Decodable {
  let userId: Int
  let email: String
  let username: String
  let createdAt: String
  let name: String
}

struct Comment: Decodable {
  let commentId: Int
  let postId: Int
  let userId: Int
  let text: String
  let createdAt: String
  let user: User
  var isLiked: Bool
}

struct ImageDTO: Decodable {
  let imageId: Int
  let postId: Int
  let height: Int
  let width: Int
  let imageBlobUrl: String
  let displayOrder: Int
}

struct Post: Decodable {
  let postId: Int
  let userId: Int
  let text: String?
  let createdAt: String
}

struct DetailedPost: Decodable, Equatable, Identifiable {
  let post: Post
  let user: User
  var isLiked: Bool
  var commentCount: Int
  var images: [ImageDTO]?

  var id: Int { post.postId }

  static func == (lhs: DetailedPost, rhs: DetailedPost) -> Bool {
    return lhs.post.postId == rhs.post.postId
  }
}
