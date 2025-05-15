import Foundation
import SwiftUI

struct CommentsView: View {
  var isShowingInSheet: Bool
  @StateObject private var viewModel: ViewModel
  @State private var newCommentText: String = ""
  @FocusState private var isTextFieldFocused: Bool
  @Environment(\.presentationMode) var presentationMode

  init(postId: Int, isShowingInSheet: Bool = true) {
    _viewModel = StateObject(wrappedValue: ViewModel(postId: postId))
    self.isShowingInSheet = isShowingInSheet
  }

  init(postId: Int, isShowingInSheet: Bool = true, viewModel: ViewModel) {
    self.isShowingInSheet = isShowingInSheet
    _viewModel = StateObject(wrappedValue: viewModel)
  }

  var body: some View {
    VStack(spacing: 0) {
      if isShowingInSheet {
        ZStack {
          VStack(spacing: 8) {
            Text("Comments")
              .font(.headline)
              .fontWeight(.bold)
              .padding()
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
      } else {
        Text("Comments")
          .fontWeight(.bold)
          .font(.title3)
          .padding()
      }

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
      } else {
        ScrollView {
          ForEach(viewModel.comments, id: \.commentId) { comment in
            CommentRow(
              comment: comment,
              toggleLike: {
                viewModel.toggleLike(for: comment)
              }
            )
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
          }
        }
      }

      if isShowingInSheet {
        Spacer()
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
        .disabled(
          newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        )
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
    .onOpenURL { url in
      presentationMode.wrappedValue.dismiss()
    }
    .presentationDragIndicator(.visible)
  }

  private func submitComment() {
    guard
      !newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else { return }

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
    dateFormatter.formatOptions = [
      .withInternetDateTime, .withFractionalSeconds,
    ]
    return dateFormatter.date(from: comment.createdAt) ?? Date()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 2) {
          if let displayName = comment.user.name, !displayName.isEmpty {
            Text(displayName)
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

      }
      .allowsHitTesting(true)

      ContentTextView(text: comment.text, facets: [])

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
        .font(.system(size: 18))
        .padding(8)
    }
    .buttonStyle(.plain)
  }
}

#Preview {
  let mockViewModel = CommentsView.ViewModel(postId: 1, service: MockCommentService())

  CommentsView(postId: 1, isShowingInSheet: true, viewModel: mockViewModel)
}

#Preview("Loading") {
  let mockViewModel = CommentsView.ViewModel(postId: 1, service: MockCommentService_Loading())

  CommentsView(postId: 1, isShowingInSheet: true, viewModel: mockViewModel)
}

#Preview("No Comments") {
  let mockViewModel = CommentsView.ViewModel(postId: 1, service: MockCommentService_Empty())

  CommentsView(postId: 1, isShowingInSheet: true, viewModel: mockViewModel)
}

#Preview("Error") {
  let mockViewModel = CommentsView.ViewModel(postId: 1, service: MockCommentService_Error())

  CommentsView(postId: 1, isShowingInSheet: true, viewModel: mockViewModel)
}
