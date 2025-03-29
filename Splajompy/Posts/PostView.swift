//
//  PostView.swift
//  Splajompy
//
//  Created by Wesley Weisenberger on 3/25/25.
//

import SwiftUI
import Foundation

struct PostView: View {
    let post: Post
    
    let formatter = RelativeDateTimeFormatter()
    
    var onLikeButtonTapped: () -> Void = { fatalError("Unimplemented: PostView.onDeleteButtonTapped") }
    
    private var postDate: Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: post.CreatedAt) ?? Date()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    if let displayName = post.Name {
                        Text(displayName)
                            .font(.title2)
                            .fontWeight(.black)
                            .lineLimit(1)
                        
                        Text("@\(post.Username)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.gray)
                    } else {
                        Text("@\(post.Username)")
                            .font(.title3)
                            .fontWeight(.black)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                // TODO
                Image(systemName: "ellipsis")
            }
            
            if let postText = post.Text {
                Text(postText)
                    .font(.body)
                    .multilineTextAlignment(.leading)
            }
            
            
            if let images = post.Images, !images.isEmpty {
                ImageCarousel(imageUrls: images.map { $0.ImageBlobUrl })
            }
            
            HStack {
                Text(formatter.localizedString(for: postDate, relativeTo: Date()))
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                HStack(spacing: 16) {
                    NavigationLink {
                        CommentsView(postId: post.PostID)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "bubble.right")
                                .font(.system(size: 16))
                            Text("\(post.Commentcount)")
                                .font(.subheadline)
                        }
                        .foregroundStyle(.white)
                    }
                    
                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        onLikeButtonTapped()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: post.Liked ? "heart.fill" : "heart")
                                .font(.system(size: 16))
                        }
                        .foregroundColor(post.Liked ? .white : .primary)
                    }
                }
            }
        }
        .padding(.vertical)
        .padding(.horizontal, 16)
        .overlay(
            Rectangle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                .mask(
                    VStack(spacing: 0) {
                        Rectangle().frame(height: 1)
                        Spacer()
                        Rectangle().frame(height: 1)
                    }
                )
        )
    }
}

struct PostView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                PostView(
                    post: Post(
                        PostID: 123,
                        Text: "This is a sample post with some text content that might span multiple lines in the UI.",
                        CreatedAt: "2025-03-20 10:19:20",
                        UserID: 5,
                        Username: "wesleynw",
                        Name: "Wesley",
                        Commentcount: 5,
                        Liked: false
                    )
                )
                PostView(
                    post: Post(
                        PostID: 123,
                        Text: "This is a sample post with some text content that might span multiple lines in the UI.",
                        CreatedAt: "2025-03-25 10:19:20",
                        UserID: 5,
                        Username: "wesleynw",
                        Name: "Wesley",
                        Commentcount: 5,
                        Liked: false,
                        Images: [
                            ImageDTO(
                                ImageID: 220,
                                PostID: 536,
                                Height: 130,
                                Width: 98,
                                ImageBlobUrl: "development/posts/1/c19201ac-ca86-4abf-a7fe-205d6bb7f92a.png",
                                DisplayOrder: 5
                            ),
                            ImageDTO(
                                ImageID: 220,
                                PostID: 536,
                                Height: 130,
                                Width: 98,
                                ImageBlobUrl: "development/posts/1/e8acd749-9bf5-4e3a-993d-a50453108bbb.png",
                                DisplayOrder: 5
                            ),
                            ImageDTO(
                                ImageID: 220,
                                PostID: 536,
                                Height: 130,
                                Width: 98,
                                ImageBlobUrl: "development/posts/1/c19201ac-ca86-4abf-a7fe-205d6bb7f92a.png",
                                DisplayOrder: 5
                            )
                        ]

                    )
                )
            }
        }
        
        .previewLayout(.sizeThatFits)
    }
}
