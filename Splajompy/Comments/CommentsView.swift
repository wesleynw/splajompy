import SwiftUI
import Foundation

struct CommentsView: View {
    @StateObject private var viewModel: ViewModel
    @State private var newCommentText: String = ""
    
    init(postId: Int) {
        _viewModel = StateObject(wrappedValue: ViewModel(postId: postId))
    }
    
    var body: some View {
        VStack {
            List {
                ForEach(viewModel.comments, id: \.CommentID) { comment in
                    CommentRow(comment: comment, toggleLike: {
                        viewModel.toggleLike(for: comment)
                        print("liking comment with ID: \(comment.CommentID)")
                    })
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
                }
            }
            .listStyle(.plain)
            
            HStack {
                TextField("Add a comment...", text: $newCommentText)
                    .padding(10)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(20)
                
                Button(action: {
                    submitComment()
                }) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.blue)
                }
                .disabled(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(UIColor.systemBackground))
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: -1)
        }
    }
    
    private func submitComment() {
        guard !newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Call viewModel to submit the comment
        // viewModel.submitComment(text: newCommentText)
        print("Submitting comment: \(newCommentText)")
        
        // Clear the input field
        newCommentText = ""
    }
}

struct CommentRow: View {
    let comment: Comment
    let toggleLike: () -> Void
    
    let formatter = RelativeDateTimeFormatter()
    
    private var commentDate: Date {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return dateFormatter.date(from: comment.CreatedAt) ?? Date()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    if let displayName = comment.User.Name {
                        Text(displayName)
                            .font(.headline)
                            .fontWeight(.bold)
                            .lineLimit(1)
                        
                        Text("@\(comment.User.Username)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    } else {
                        Text("@\(comment.User.Username)")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                // Menu button for comment actions (report, delete, etc.)
                Button(action: {
                    // Add action for comment menu
                }) {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.gray)
                }
            }
            
            Text(comment.Text)
                .font(.body)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            
            HStack {
                Text(formatter.localizedString(for: commentDate, relativeTo: Date()))
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                // Use the LikeButton component instead of defining the button inline
                LikeButton(isLiked: comment.IsLiked, action: toggleLike)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color.clear) // Clear background to ensure taps go to buttons, not row
        .overlay(
            Rectangle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                .mask(
                    VStack(spacing: 0) {
                        Spacer()
                        Rectangle().frame(height: 1)
                    }
                )
        )
    }
}

struct LikeButton: View {
    let isLiked: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .foregroundColor(isLiked ? .white : .gray)
                    .font(.system(size: 18))
            }
            .contentShape(Rectangle()) // Ensures the tap area includes the entire HStack
            .onTapGesture {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
                action()
            }
        }
        .buttonStyle(PlainButtonStyle()) // Prevents button styling from affecting tap area
    }
}
