import Foundation
import PostHog
import SwiftUI

struct CommentsView: View {
  var isShowingInSheet: Bool
  var postId: Int
  @StateObject private var viewModel: ViewModel
  @State private var showingCommentSheet = false
  @FocusState private var isTextFieldFocused: Bool
  @Environment(\.presentationMode) var presentationMode

  init(postId: Int, isShowingInSheet: Bool = true) {
    self.postId = postId
    _viewModel = StateObject(wrappedValue: ViewModel(postId: postId))
    self.isShowingInSheet = isShowingInSheet
  }

  init(postId: Int, isShowingInSheet: Bool = true, viewModel: ViewModel) {
    self.postId = postId
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

      Divider()

      Button(action: {
        showingCommentSheet = true
      }) {
        HStack {
          Spacer()
          Image(systemName: "plus.circle.fill")
            .font(.system(size: 20))
          Text("Add a comment")
            .fontWeight(.medium)
          Spacer()
        }
      }
      .padding([.top, .leading, .trailing])
      .buttonStyle(.plain)
    }
    .sheet(isPresented: $showingCommentSheet) {
      AddCommentSheet(viewModel: viewModel)
    }
    .onTapGesture {
      if isTextFieldFocused {
        isTextFieldFocused = false
      }
    }
    .animation(.easeInOut, value: true)
    .onOpenURL { url in
      if !isShowingInSheet {
        return
      }
      presentationMode.wrappedValue.dismiss()
    }
    .presentationDragIndicator(.visible)
    .postHogScreenView("CommentsView", ["post": postId])
  }
}

struct AddCommentSheet: View {
  @ObservedObject var viewModel: CommentsView.ViewModel
  @State private var text = NSAttributedString(string: "")
  @Environment(\.presentationMode) var presentationMode

  var body: some View {
    VStack(spacing: 12) {
      HStack {
        Spacer()
        Button("Comment") {
          submitComment()
        }
        .disabled(
          text.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        )
        .fontWeight(.semibold)
        .font(.headline)
      }
      .padding([.top, .leading, .trailing])

      MentionTextEditor(text: $text, showSuggestionsOnTop: false)
        .frame(minHeight: 80)
        .padding(.horizontal, 16)

      Spacer()
    }
    .presentationDragIndicator(.visible)
  }

  private func submitComment() {
    let commentText = text.string.trimmingCharacters(
      in: .whitespacesAndNewlines
    )
    guard !commentText.isEmpty else { return }

    viewModel.addComment(text: commentText)
    presentationMode.wrappedValue.dismiss()
  }
}

struct CommentRow: View {
  let comment: DetailedComment
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

      ContentTextView(text: comment.text, facets: comment.facets ?? [])

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
  let mockViewModel = CommentsView.ViewModel(
    postId: 1,
    service: MockCommentService()
  )

  CommentsView(postId: 1, isShowingInSheet: true, viewModel: mockViewModel)
}

#Preview("Loading") {
  let mockViewModel = CommentsView.ViewModel(
    postId: 1,
    service: MockCommentService_Loading()
  )

  CommentsView(postId: 1, isShowingInSheet: true, viewModel: mockViewModel)
}

#Preview("No Comments") {
  let mockViewModel = CommentsView.ViewModel(
    postId: 1,
    service: MockCommentService_Empty()
  )

  CommentsView(postId: 1, isShowingInSheet: true, viewModel: mockViewModel)
}

#Preview("Error") {
  let mockViewModel = CommentsView.ViewModel(
    postId: 1,
    service: MockCommentService_Error()
  )

  CommentsView(postId: 1, isShowingInSheet: true, viewModel: mockViewModel)
}
