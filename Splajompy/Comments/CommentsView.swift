import Foundation
import SwiftUI

struct CommentsView: View {
  @StateObject private var viewModel: ViewModel
  @State private var newCommentText: String = ""
  @FocusState private var isTextFieldFocused: Bool
  @Environment(\.presentationMode) var presentationMode

  init(postId: Int) {
    _viewModel = StateObject(wrappedValue: ViewModel(postId: postId))
  }

  var body: some View {
    VStack(spacing: 0) {
      ZStack {
        VStack(spacing: 8) {
          Rectangle()
            .fill(Color.gray.opacity(0.4))
            .frame(width: 40, height: 5)
            .cornerRadius(2.5)
            .padding(.top, 8)

          Text("Comments")
            .font(.headline)
            .fontWeight(.bold)
            .padding(.bottom, 16)
        }

        HStack {
          Spacer()
          Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            presentationMode.wrappedValue.dismiss()
          }) {
            Image(systemName: "xmark.circle.fill")
              .font(.system(size: 24))
              .foregroundColor(Color.gray.opacity(0.7))
          }
          .padding(.top, 8)
          .padding(.trailing, 16)
        }
      }
      .frame(maxWidth: .infinity)
      .background(Color(UIColor.systemBackground))
      .contentShape(Rectangle())

      Rectangle()
        .fill(Color.gray.opacity(0.2))
        .frame(height: 1)

      ZStack {
        if viewModel.isLoading {
          ProgressView()
            .scaleEffect(1.5)
            .padding()
        } else if viewModel.comments.isEmpty {
          VStack(spacing: 16) {
            Spacer()
            Text("No comments")
              .font(.title3)
              .foregroundColor(.gray)
            Spacer()
          }
        }

        List {
          ForEach(viewModel.comments, id: \.commentId) { comment in
            CommentRow(
              comment: comment,
              toggleLike: {
                viewModel.toggleLike(for: comment)
                print("liking comment with ID: \(comment.commentId)")
              }
            )
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
          }
        }
        .listStyle(.plain)
        .environment(\.defaultMinListRowHeight, 0)
      }

      HStack {
        TextField("Add a comment...", text: $newCommentText)
          .padding(10)
          .background(Color(UIColor.systemGray6))
          .cornerRadius(20)
          .focused($isTextFieldFocused)

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
    .onTapGesture {
      if isTextFieldFocused {
        isTextFieldFocused = false
      }
    }
    .animation(.easeInOut, value: true)
  }

  private func submitComment() {
    guard !newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

    print("Submitting comment: \(newCommentText)")
    viewModel.addComment(text: newCommentText)
    newCommentText = ""
    isTextFieldFocused = false  // dismiss keyboard
  }
}

struct CommentRow: View {
  let comment: Comment
  let toggleLike: () -> Void

  let formatter = RelativeDateTimeFormatter()

  private var commentDate: Date {
    let dateFormatter = ISO8601DateFormatter()
    dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return dateFormatter.date(from: comment.createdAt) ?? Date()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 2) {
          if !comment.user.name.isEmpty {
            Text(comment.user.name)
              .font(.headline)
              .fontWeight(.bold)
              .lineLimit(1)

            Text("@\(comment.user.username)")
              .font(.subheadline)
              .foregroundColor(.gray)
          } else {
            Text("@\(comment.user.username)")
              .font(.headline)
              .fontWeight(.bold)
              .foregroundColor(.gray)
          }
        }

        Spacer()

        Button(action: {
          // TODO: add action for comment menu
        }) {
          Image(systemName: "ellipsis")
            .foregroundColor(.gray)
        }
      }
      .allowsHitTesting(true)

      Text(comment.text)
        .font(.body)
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
        .allowsHitTesting(false)

      HStack {
        Text(formatter.localizedString(for: commentDate, relativeTo: Date()))
          .font(.caption)
          .foregroundColor(.gray)
          .allowsHitTesting(false)

        Spacer()

        LikeButton(isLiked: comment.isLiked, action: toggleLike)
          .allowsHitTesting(true)
      }
      .allowsHitTesting(true)
    }
    .padding(.vertical, 12)
    .padding(.horizontal, 16)
    .background(Color(UIColor.systemBackground))
    .contentShape(Rectangle())
    .onLongPressGesture(minimumDuration: .infinity) {}
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
    Button(action: {
      let impact = UIImpactFeedbackGenerator(style: .light)
      impact.impactOccurred()
      action()
    }) {
      Image(systemName: isLiked ? "heart.fill" : "heart")
        .foregroundColor(isLiked ? .white : .gray)
        .font(.system(size: 18))
        .padding(8)
    }
    .buttonStyle(BorderlessButtonStyle())
  }
}
