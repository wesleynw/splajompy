import PostHog
import SwiftUI

struct CommentsView: View {
  var postId: Int
  var isInSheet: Bool
  var showInput: Bool

  @ObservedObject var postManager: PostManager

  @StateObject private var viewModel: ViewModel
  @Environment(\.dismiss) private var dismiss

  @State private var cursorY: CGFloat = 0
  @FocusState private var isInputFocused: Bool
  #if os(iOS)
    @StateObject private var mentionViewModel =
      MentionTextEditor.MentionViewModel()
  #endif

  init(postId: Int, postManager: PostManager, isInSheet: Bool = true, showInput: Bool = true) {
    self.postId = postId
    self.postManager = postManager
    _viewModel = StateObject(
      wrappedValue: ViewModel(postId: postId, postManager: postManager)
    )
    self.isInSheet = isInSheet
    self.showInput = showInput
  }

  init(
    postId: Int,
    postManager: PostManager,
    viewModel: ViewModel,
    isInSheet: Bool = true,
    showInput: Bool = true
  ) {
    self.postId = postId
    self.postManager = postManager
    _viewModel = StateObject(wrappedValue: viewModel)
    self.isInSheet = isInSheet
    self.showInput = showInput
  }

  var body: some View {
    if isInSheet {
      NavigationStack {
        content
          .navigationTitle("Comments")
          #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
          #endif
          .toolbar {
            ToolbarItem(
              placement: {
                #if os(iOS)
                  .topBarTrailing
                #else
                  .primaryAction
                #endif
              }()
            ) {
              if #available(iOS 26, macOS 26, *) {
                Button(role: .cancel, action: { dismiss() })
              } else {
                Button {
                  dismiss()
                } label: {
                  Image(systemName: "xmark.circle.fill")
                    .opacity(0.75)
                }
                .buttonStyle(.plain)
              }
            }
          }
      }
    } else {
      content
    }
  }

  @ViewBuilder
  var content: some View {
    VStack(spacing: 0) {
      if !isInSheet {
        HStack {
          Text("Comments")
            .fontWeight(.bold)
            .font(.title3)
            .padding()

          Spacer()
        }
      }

      switch viewModel.state {
      case .idle:
        EmptyView()
      case .loading:
        VStack {
          Spacer()
          ProgressView()
            .scaleEffect(1.5)
            .padding()
          Spacer()
        }
      case .loaded(let comments):
        if comments.isEmpty {
          VStack(spacing: 16) {
            Spacer()
            Text("No comments")
              .font(.title3)
              .foregroundColor(.gray)
            Spacer()
          }
        } else {
          ScrollView {
            ForEach(comments, id: \.commentId) { comment in
              CommentRow(
                comment: comment,
                toggleLike: {
                  viewModel.toggleLike(for: comment)
                },
                deleteComment: {
                  Task {
                    await viewModel.deleteComment(comment)
                    postManager.updatePost(id: postId) { post in
                      post.commentCount -= 1
                    }
                  }
                }
              )
            }
          }
          .onTapGesture {
            isInputFocused = false
          }
          .animation(.easeInOut(duration: 0.3), value: comments)
        }
      case .failed(let error):
        ErrorScreen(
          errorString: error.localizedDescription,
          onRetry: viewModel.loadComments
        )
      }

      if showInput {
        Divider()

        #if os(iOS)
          HStack(alignment: .bottom, spacing: 8) {
            MentionTextEditor(
              text: $viewModel.text,
              viewModel: mentionViewModel,
              cursorY: $cursorY,
              cursorPosition: $viewModel.cursorPosition,
              isCompact: true
            )
            .focused($isInputFocused)

            Button(action: {
              Task {
                let result = await viewModel.submitComment(text: viewModel.text.string)
                if result == true {
                  viewModel.resetInputState()
                  postManager.updatePost(id: postId) { post in
                    post.commentCount += 1
                  }
                }
              }
            }) {
              if viewModel.isSubmitting {
                ProgressView()
                  .frame(width: 32, height: 32)
              } else {
                Image(systemName: "arrow.up.circle.fill")
                  .font(.system(size: 32))
              }
            }
            .disabled(
              viewModel.text.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || viewModel.isSubmitting
            )
          }

          .padding(.horizontal, 12)
          .padding(.vertical, 8)
        #endif
      }
    }
    #if os(iOS)
      .overlay(alignment: .bottomLeading) {
        if showInput && mentionViewModel.isShowingSuggestions {
          MentionTextEditor.suggestionView(
            suggestions: mentionViewModel.mentionSuggestions,
            onInsert: { user in
              let result = mentionViewModel.insertMention(
                user,
                in: viewModel.text,
                at: viewModel.cursorPosition
              )
              viewModel.text = result.text
              viewModel.cursorPosition = result.newCursorPosition
            }
          )
          .padding(.horizontal, 16)
          .padding(.bottom, 60)
          .animation(.default, value: mentionViewModel.isShowingSuggestions)
        }
      }
    #endif
    .alert(
      "Error submitting comment",
      isPresented: $viewModel.showError,
      actions: {
        Button("OK") {
          viewModel.showError = false
        }
      }
    ) {
      Text(viewModel.errorMessage ?? "An error occurred while submitting your comment.")
    }
    .animation(.easeInOut, value: true)
    .onOpenURL { url in
      if !isInSheet {
        return
      }
      dismiss()
    }
    .presentationDragIndicator(.visible)
    .postHogScreenView("CommentsView", ["post": postId])
  }
}

struct CommentRow: View {
  let comment: DetailedComment
  let toggleLike: () -> Void
  let deleteComment: () -> Void

  let formatter = RelativeDateTimeFormatter()

  @EnvironmentObject private var authManager: AuthManager

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

        HStack(spacing: 0) {
          if let currentUser = authManager.getCurrentUser() {
            if currentUser.userId == comment.user.userId {
              Menu(
                content: {
                  Button(role: .destructive, action: { deleteComment() }) {
                    Label("Delete", systemImage: "trash")
                      .foregroundColor(.red)
                  }
                },
                label: {
                  Image(systemName: "ellipsis")
                    .font(.system(size: 16))
                    .frame(width: 32, height: 32)
                }
              )
              .buttonStyle(.plain)
            }
          }

          LikeButton(isLiked: comment.isLiked, action: toggleLike)
            .allowsHitTesting(true)
        }
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
        .foregroundStyle(isLiked ? Color.red.gradient : Color.primary.gradient)
        .padding(6)
        .scaleEffect(isLiked ? 1.1 : 1)
        .animation(
          .spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0),
          value: isLiked
        )
    }
    .buttonStyle(.plain)
    .sensoryFeedback(.impact, trigger: isLiked)
  }
}

#Preview {
  let mockViewModel = CommentsView.ViewModel(
    postId: 1,
    service: MockCommentService(),
    postManager: PostManager()
  )

  let postManager = PostManager()

  CommentsView(
    postId: 1,
    postManager: postManager,
    viewModel: mockViewModel
  )
}

#Preview("Loading") {
  let mockViewModel = CommentsView.ViewModel(
    postId: 1,
    service: MockCommentService_Loading(),
    postManager: PostManager()
  )

  let postManager = PostManager()

  CommentsView(
    postId: 1,
    postManager: postManager,
    viewModel: mockViewModel
  )
  .environmentObject(AuthManager())
}

#Preview("No Comments") {
  let mockViewModel = CommentsView.ViewModel(
    postId: 1,
    service: MockCommentService_Empty(),
    postManager: PostManager()
  )

  let postManager = PostManager()

  CommentsView(
    postId: 1,
    postManager: postManager,
    viewModel: mockViewModel
  )
  .environmentObject(AuthManager())
}

#Preview("Error") {
  let mockViewModel = CommentsView.ViewModel(
    postId: 1,
    service: MockCommentService_Error(),
    postManager: PostManager()
  )

  let postManager = PostManager()

  CommentsView(
    postId: 1,
    postManager: postManager,
    viewModel: mockViewModel
  )
  .environmentObject(AuthManager())
}
