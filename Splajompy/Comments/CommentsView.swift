import PostHog
import SwiftUI

struct CommentsView: View {
  var isShowingInSheet: Bool
  var postId: Int

  @ObservedObject var postManager: PostManager

  @StateObject private var viewModel: ViewModel
  @State private var showingCommentSheet = false
  @FocusState private var isTextFieldFocused: Bool
  @Environment(\.dismiss) private var dismiss

  init(postId: Int, isShowingInSheet: Bool = true, postManager: PostManager) {
    self.postId = postId
    self.isShowingInSheet = isShowingInSheet
    self.postManager = postManager
    _viewModel = StateObject(wrappedValue: ViewModel(postId: postId))
  }

  init(
    postId: Int,
    postManager: PostManager,
    isShowingInSheet: Bool = true,
    viewModel: ViewModel
  ) {
    self.postId = postId
    self.isShowingInSheet = isShowingInSheet
    self.postManager = postManager
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
              dismiss()
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
        .contentShape(Rectangle())

        Rectangle()
          .fill(Color.gray.opacity(0.2))
          .frame(height: 1)
      } else {
        HStack {
          Text("Comments")
            .fontWeight(.bold)
            .font(.title3)
            .padding()

          Spacer()
        }
      }

      if viewModel.isLoading {
        VStack {
          Spacer()
          ProgressView()
            .scaleEffect(1.5)
            .padding()
          Spacer()
        }
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
          Text("Comment")
            .fontWeight(.medium)
          Spacer()
        }
      }
      .padding([.top, .leading, .trailing])
      .buttonStyle(.plain)
    }
    .sheet(isPresented: $showingCommentSheet) {
      AddCommentSheet(
        viewModel: viewModel,
        postId: postId,
        postManager: postManager
      )
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
      dismiss()
    }
    .presentationDragIndicator(.visible)
    .postHogScreenView("CommentsView", ["post": postId])
  }
}

struct AddCommentSheet: View {
  @ObservedObject var viewModel: CommentsView.ViewModel
  @State private var text = NSAttributedString(string: "")
  @Environment(\.dismiss) var dismiss
  let postId: Int
  let postManager: PostManager

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

      #if os(iOS)
        MentionTextEditor(text: $text, showSuggestionsOnTop: false)
          .frame(minHeight: 80)
          .padding(.horizontal, 16)
      #endif

      Spacer()
    }
    .presentationDragIndicator(.visible)
  }

  private func submitComment() {
    let commentText = text.string.trimmingCharacters(
      in: .whitespacesAndNewlines
    )
    guard !commentText.isEmpty else { return }

    Task {
      await viewModel.submitComment(text: commentText)

      postManager.updatePost(id: postId) { post in
        post.commentCount += 1
      }

      await MainActor.run {
        dismiss()
      }
    }
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
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .firstTextBaseline, spacing: 4) {
        if let displayName = comment.user.name, !displayName.isEmpty {
          Text(displayName)
            .font(.headline)
            .fontWeight(.bold)
            .lineLimit(1)

          Text("@\(comment.user.username)")
            .font(.subheadline)
            .foregroundColor(.gray)
            .lineLimit(1)
        } else {
          Text("@\(comment.user.username)")
            .font(.headline)
            .fontWeight(.bold)
            .foregroundColor(.gray)
        }
      }

      ContentTextView(attributedText: comment.richContent)

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
    .padding(.vertical, 8)
    #if os(iOS)
      .padding(.horizontal, 16)
    #else
      .padding(.horizontal, 24)
    #endif
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
      action()
    }) {
      Image(systemName: isLiked ? "heart.fill" : "heart")
        .font(.system(size: 16))
        .padding(6)
    }
    .buttonStyle(.plain)
    .sensoryFeedback(.impact, trigger: isLiked)
  }
}

#Preview {
  let mockViewModel = CommentsView.ViewModel(
    postId: 1,
    service: MockCommentService()
  )

  let postManager = PostManager()

  CommentsView(
    postId: 1,
    postManager: postManager,
    isShowingInSheet: true,
    viewModel: mockViewModel
  )
}

#Preview("Loading") {
  let mockViewModel = CommentsView.ViewModel(
    postId: 1,
    service: MockCommentService_Loading()
  )

  let postManager = PostManager()

  CommentsView(
    postId: 1,
    postManager: postManager,
    isShowingInSheet: true,
    viewModel: mockViewModel
  )
}

#Preview("No Comments") {
  let mockViewModel = CommentsView.ViewModel(
    postId: 1,
    service: MockCommentService_Empty()
  )

  let postManager = PostManager()

  CommentsView(
    postId: 1,
    postManager: postManager,
    isShowingInSheet: true,
    viewModel: mockViewModel
  )
}

#Preview("Error") {
  let mockViewModel = CommentsView.ViewModel(
    postId: 1,
    service: MockCommentService_Error()
  )

  let postManager = PostManager()

  CommentsView(
    postId: 1,
    postManager: postManager,
    isShowingInSheet: true,
    viewModel: mockViewModel
  )
}
