import Foundation
import SwiftUI

struct PostView: View {
  let post: DetailedPost
  var showAuthor: Bool = true
  let formatter = RelativeDateTimeFormatter()
  var onLikeButtonTapped: () -> Void = { print("Unimplemented: PostView.onDeleteButtonTapped") }

  @State private var isShowingComments = false

  private var postDate: Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.date(from: post.post.createdAt) ?? Date()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      if showAuthor {
        HStack(alignment: .top) {
          NavigationLink {
            ProfileView(userId: post.user.userId, username: post.user.username, isOwnProfile: false)
          } label: {
            VStack(alignment: .leading, spacing: 2) {
              if !post.user.name.isEmpty {
                Text(post.user.name)
                  .font(.title2)
                  .fontWeight(.black)
                  .lineLimit(1)
                Text("@\(post.user.username)")
                  .font(.subheadline)
                  .fontWeight(.bold)
                  .foregroundColor(.gray)
              } else {
                Text("@\(post.user.username)")
                  .font(.title3)
                  .fontWeight(.black)
                  .foregroundColor(.gray)
              }
            }
          }
          .foregroundColor(.primary)
          Spacer()
          // TODO
          // Image(systemName: "ellipsis")
        }
      }
      if let postText = post.post.text {
        Text(postText)
          .font(.body)
          .multilineTextAlignment(.leading)
      }
      if let images = post.images, !images.isEmpty {
        ImageCarousel(imageUrls: images.map { $0.imageBlobUrl })
      }
      HStack {
        Text(formatter.localizedString(for: postDate, relativeTo: Date()))
          .font(.caption)
          .foregroundColor(.gray)
        Spacer()
        HStack(spacing: 16) {
          // Replace NavigationLink with Button
          Button(action: {
            // Add haptic feedback
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            // Show comment sheet
            isShowingComments = true
          }) {
            HStack(spacing: 4) {
              Text("\(post.commentCount)")
                .font(.subheadline)
              Image(systemName: "bubble.right")
                .font(.system(size: 20))
            }
            .foregroundStyle(.white)
          }

          Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            onLikeButtonTapped()
          }) {
            HStack(spacing: 4) {
              Image(systemName: post.isLiked ? "heart.fill" : "heart")
                .font(.system(size: 20))
            }
            .foregroundColor(post.isLiked ? .white : .primary)
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
    .sheet(isPresented: $isShowingComments) {
      CommentsView(postId: post.post.postId)
    }
  }
}
