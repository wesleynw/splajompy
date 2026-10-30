import PhotosUI
import SwiftUI

private struct SelectedImage: Identifiable {
  var id: Int
  var image: PlatformImage
}

struct CommentInputView: View {
  @Bindable var viewModel: CommentsContainerView.ViewModel

  @State private var mentionViewModel =
    MentionTextEditor.MentionViewModel()
  @State private var cursorRect: CGRect = CGRectZero
  @State private var submitButtonWidth: CGFloat = 0
  @State private var presentingImage: SelectedImage? = nil

  var replyNamespace: Namespace.ID?
  @Namespace private var namespace

  @FocusState private var focus

  var body: some View {
    VStack {
      VStack {
        ViewThatFits(in: .vertical) {
          inputTopAccessories

          ScrollView {
            inputTopAccessories
          }
        }

        HStack(alignment: .bottom, spacing: 0) {
          PhotosPicker(
            selection: $viewModel.imageSelection,
            matching: .images
          ) {
            Image(systemName: "plus.circle.fill")
              .resizable()
              .frame(width: 32, height: 32)
              .padding(5)
          }
          .buttonStyle(.plain)
          .disabled(viewModel.imageState != .empty)

          ZStack(alignment: .top) {
            MentionTextEditor(
              text: $viewModel.text,
              viewModel: mentionViewModel,
              cursorRect: $cursorRect,
              selectedRange: $viewModel.selectedRange,
              isCompact: true,
              trailingInset: submitButtonWidth
            )
            .focused($focus)
            .overlay(alignment: .bottomTrailing) {
              Button(action: {
                mentionViewModel.clearMentionState()
                Task {
                  await viewModel.submitComment()
                }
              }) {
                if viewModel.isSubmitting {
                  ProgressView()
                    .frame(width: 32, height: 32)
                    #if os(macOS)
                      .controlSize(.small)
                    #endif
                } else {
                  Image(systemName: "arrow.up.circle.fill")
                    .resizable()
                    .frame(width: 32, height: 32)
                }
              }
              .disabled(isSubmitButtonDisabled)
              #if os(macOS)
                .buttonStyle(.plain)
              #endif
              .padding(5)
              .onGeometryChange(for: CGFloat.self) {
                $0.size.width
              } action: {
                submitButtonWidth = $0
              }
            }
            .layoutPriority(1)

            VStack(spacing: 0) {
              if mentionViewModel.isShowingSuggestions {
                suggestionOverlay
              }
            }
            .offset(y: cursorRect.minY - 5)
            .alignmentGuide(.top) { dimensions in
              dimensions[.bottom]
            }
            .animation(.default, value: mentionViewModel.isShowingSuggestions)
          }
        }
      }
      .modify {
        if #available(anyAppleOS 26, *) {
          $0
            .containerShape(RoundedRectangle(cornerRadius: 25))
            .glassEffect(
              .regular.tint(.clear.opacity(0.15)).interactive(),
              in: RoundedRectangle(cornerRadius: 25)
            )
            .padding()
        } else {
          $0
            .padding(8)
            .background(.bar)
            .overlay(alignment: .top) {
              Divider()
            }
        }
      }
    }
    .onChange(of: viewModel.respondingToComment?.commentId) { _, newValue in
      focus = newValue != nil
    }
    .sheet(item: $presentingImage) { selected in
      LocalImagePager(
        images: [selected.image],
        currentIndex: .constant(0),
        onDismiss: { presentingImage = nil }
      )
      #if os(iOS)
        .modify {
          if #available(iOS 18, *) {
            $0.navigationTransition(.zoom(sourceID: "zoom", in: namespace))
          }
        }
      #endif
    }
    #if os(macOS)
      .frame(maxWidth: 600)
    #endif
  }

  @ContentBuilder
  private var inputTopAccessories: some View {
    VStack {
      if let replyingComment = viewModel.respondingToComment {
        CommentView(
          comment: replyingComment,
          onToggleLike: { comment in },
          onDelete: { commentId in },
          onCommentReply: {},
          isReadOnly: true,
          showChildren: false,
          replyNamespace: replyNamespace,
        )
        .allowsHitTesting(false)
        .padding(.top)
        .overlay(alignment: .topTrailing) {
          Button {
            withAnimation {
              viewModel.unstageCommentReply()
            }
          } label: {
            Image(systemName: "xmark.circle.fill")
              .imageScale(.medium)
              .padding()
          }
          .buttonStyle(.plain)
        }
      }

      if viewModel.imageState != .empty {
        ScrollView(.horizontal) {
          HStack {
            ImagePreviewView(
              state: viewModel.imageState,
              onRetry: {
                viewModel.retryImage()
              },
              onRemove: {
                viewModel.imageSelection = nil
              },
              onTap: {
                if let photo = viewModel.imageState.image {
                  presentingImage = SelectedImage(id: 0, image: photo)
                }
              },
              onRetryUpload: {
                viewModel.retryUpload()
              }
            )
            .modify {
              if #available(iOS 18, *) {
                $0.matchedTransitionSource(id: "zoom", in: namespace)
              }
            }
            .disabled(viewModel.isSubmitting)
          }
        }
        .scrollIndicators(.hidden)
      }
    }
  }

  private var suggestionOverlay: some View {
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
    .padding(.horizontal)
  }

  private var isSubmitButtonDisabled: Bool {
    let hasImage = viewModel.imageState.hasPhoto
    let textEmpty = viewModel.text.string.trimmingCharacters(
      in: .whitespacesAndNewlines
    ).isEmpty

    return (textEmpty && !hasImage) || viewModel.imageState.isFailed
      || viewModel.isSubmitting
  }
}

#Preview {
  CommentInputView(
    viewModel: CommentsContainerView.ViewModel(
      postId: 1,
      postManager: PostStore()
    )
  )
}

#Preview("responding to comment") {
  let viewModel = CommentsContainerView.ViewModel(
    postId: 1,
    postManager: PostStore()
  )
  viewModel.stageCommentReply(to: Mocks.comment1)

  return CommentInputView(
    viewModel: viewModel
  )
}
