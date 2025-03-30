//
//  PostView.swift
//  Splajompy
//
//  Created by Wesley Weisenberger on 3/25/25.
//

import SwiftUI
import Foundation

struct PostView: View {
    let post: DetailedPost
    
    let formatter = RelativeDateTimeFormatter()
    
    var onLikeButtonTapped: () -> Void = { fatalError("Unimplemented: PostView.onDeleteButtonTapped") }
    
    private var postDate: Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: post.Post.CreatedAt) ?? Date()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                NavigationLink {
                    ProfileView(userID: post.User.UserID, isOwnProfile: false)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        if let displayName = post.User.Name {
                            Text(displayName)
                                .font(.title2)
                                .fontWeight(.black)
                                .lineLimit(1)
                            
                            Text("@\(post.User.Username)")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                        } else {
                            Text("@\(post.User.Username)")
                                .font(.title3)
                                .fontWeight(.black)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .foregroundColor(.primary)
                
                Spacer()
                
                // TODO
                Image(systemName: "ellipsis")
            }
            
            if let postText = post.Post.Text {
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
                        CommentsView(postId: post.Post.PostID)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "bubble.right")
                                .font(.system(size: 16))
//                            Text("\(post.Commentcount)")
//                                .font(.subheadline)
                        }
                        .foregroundStyle(.white)
                    }
                    
                    Button(action: {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        onLikeButtonTapped()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: post.IsLiked ? "heart.fill" : "heart")
                                .font(.system(size: 16))
                        }
                        .foregroundColor(post.IsLiked ? .white : .primary)
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
