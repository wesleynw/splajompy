import PostHog
import SwiftUI

struct CommentsView: View {
  var postId: Int
  var isInSheet: Bool
  var showInput: Bool

  var postManager: PostStore

  @StateObject private var viewModel: ViewModel
  @Environment(\.dismiss) private var dismiss

  @State private var cursorY: CGFloat = 0
  @FocusState private var isInputFocused: Bool
  #if os(iOS)
    @StateObject private var mentionViewModel =
      MentionTextEditor.MentionViewModel()
  #endif

  init(
    postId: Int,
    postManager: PostStore,
    isInSheet: Bool = true,
    showInput: Bool = true
  ) {
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
    postManager: PostStore,
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
          .interactiveDismissDisabled(
            !viewModel.text.string.trimmingCharacters(
              in: .whitespacesAndNewlines
            ).isEmpty
          )
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
            .padding()
          Spacer()
        }
        .onTapGesture {
          isInputFocused = false
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
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .onTapGesture {
            isInputFocused = false
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
              selectedRange: $viewModel.selectedRange,
              isCompact: true
            )
            .focused($isInputFocused)

            Button(action: {
              Task {
                let result = await viewModel.submitComment(
                  text: viewModel.text.string
                )
                if result == true {
                  viewModel.resetInputState()
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
              viewModel.text.string.trimmingCharacters(
                in: .whitespacesAndNewlines
              ).isEmpty
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
            isLoading: mentionViewModel.isLoading,
            onInsert: { user in
              let result = mentionViewModel.insertMention(
                user,
                in: viewModel.text,
                at: viewModel.selectedRange
              )
              viewModel.text = result.text
              viewModel.selectedRange = result.newSelectedRange
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
      Text(
        viewModel.errorMessage
          ?? "An error occurred while submitting your comment."
      )
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

  @Environment(AuthManager.self) private var authManager
  @State private var showDeleteConfirmation = false

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .firstTextBaseline, spacing: 2) {
        ProfileDisplayNameView(user: comment.user, alignVertically: false)
      }

      Text(comment.richContent)

      HStack {
        TimelineView(.periodic(from: .now, by: 5)) { _ in
          Text(
            comment.createdAt
              .formatted(.relative(presentation: .named))
          )
          .font(.caption)
          .foregroundColor(.gray)
        }

        Spacer()

        HStack(spacing: 0) {
          if let currentUser = authManager.getCurrentUser() {
            if currentUser.userId == comment.user.userId {
              Menu(
                content: {
                  Button(
                    role: .destructive,
                    action: { showDeleteConfirmation = true }
                  ) {
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
    .confirmationDialog(
      "Are you sure you want to delete this comment?",
      isPresented: $showDeleteConfirmation,
      titleVisibility: .visible
    ) {
      Button("Delete", role: .destructive) {
        deleteComment()
      }
      Button("Cancel", role: .cancel) {}
    }

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
    postManager: PostStore()
  )

  let postManager = PostStore()

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
    postManager: PostStore()
  )

  let postManager = PostStore()

  CommentsView(
    postId: 1,
    postManager: postManager,
    viewModel: mockViewModel
  )
  .environment(AuthManager())
}

#Preview("No Comments") {
  let mockViewModel = CommentsView.ViewModel(
    postId: 1,
    service: MockCommentService_Empty(),
    postManager: PostStore()
  )

  let postManager = PostStore()

  CommentsView(
    postId: 1,
    postManager: postManager,
    viewModel: mockViewModel
  )
  .environment(AuthManager())
}

#Preview("Error") {
  let mockViewModel = CommentsView.ViewModel(
    postId: 1,
    service: MockCommentService_Error(),
    postManager: PostStore()
  )

  let postManager = PostStore()

  CommentsView(
    postId: 1,
    postManager: postManager,
    viewModel: mockViewModel
  )
  .environment(AuthManager())
}
