import PostHog
import SwiftUI

struct CommentsView: View {
  var postId: Int
  var isInSheet: Bool

  @ObservedObject var postManager: PostManager

  @StateObject private var viewModel: ViewModel
  @State private var showingCommentSheet = false
  @FocusState private var isTextFieldFocused: Bool
  @Environment(\.dismiss) private var dismiss

  init(postId: Int, postManager: PostManager, isInSheet: Bool = true) {
    self.postId = postId
    self.postManager = postManager
    _viewModel = StateObject(
      wrappedValue: ViewModel(postId: postId, postManager: postManager)
    )
    self.isInSheet = isInSheet
  }

  init(
    postId: Int,
    postManager: PostManager,
    viewModel: ViewModel,
    isInSheet: Bool = true
  ) {
    self.postId = postId
    self.postManager = postManager
    _viewModel = StateObject(wrappedValue: viewModel)
    self.isInSheet = isInSheet
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
                  Image(systemName: "x.circle.fill")
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
        .animation(.easeInOut(duration: 0.3), value: viewModel.comments)
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
      .padding()
      .buttonStyle(.plain)
    }
    .sheet(isPresented: $showingCommentSheet) {
      AddCommentSheet(
        viewModel: viewModel,
        postId: postId,
      )
    }
    .onTapGesture {
      if isTextFieldFocused {
        isTextFieldFocused = false
      }
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

      ContentTextView(text: comment.text, facets: comment.facets ?? [])

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
}
