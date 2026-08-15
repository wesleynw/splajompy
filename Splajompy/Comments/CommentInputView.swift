import PhotosUI
import SwiftUI

private struct SelectedImage: Identifiable {
  var id: Int
  var image: PlatformImage
}

struct CommentInputView: View {
  @Bindable var viewModel: CommentsView.ViewModel

  @State private var mentionViewModel =
    MentionTextEditor.MentionViewModel()
  @State private var cursorY: CGFloat = 0
  @State private var submitButtonWidth: CGFloat = 0
  @State private var presentingImage: SelectedImage? = nil
  @Namespace var namespace

  var body: some View {
    VStack {
      if mentionViewModel.isShowingSuggestions {
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
        .modify {
          if #available(iOS 26, macOS 26, *) {
            $0.glassEffect(
              .regular.interactive(),
              in: RoundedRectangle(cornerRadius: 15)
            )
          }
        }
        .animation(.default, value: mentionViewModel.isShowingSuggestions)
        .padding(.horizontal)
      }

      VStack {
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
                  if case .success(let photo) = viewModel.imageState {
                    presentingImage = SelectedImage(id: 0, image: photo)
                  }
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

        HStack(alignment: .bottom, spacing: 0) {
          PhotosPicker(selection: $viewModel.imageSelection, matching: .images) {
            Image(systemName: "plus.circle.fill")
              .resizable()
              .frame(width: 32, height: 32)
              .padding(5)
          }
          .buttonStyle(.plain)
          .disabled(
            {
              if case .empty = viewModel.imageState { return false }
              return true
            }()
          )

          MentionTextEditor(
            text: $viewModel.text,
            viewModel: mentionViewModel,
            cursorY: $cursorY,
            selectedRange: $viewModel.selectedRange,
            isCompact: true,
            trailingInset: submitButtonWidth
          )
          .overlay(alignment: .bottomTrailing) {
            Button(action: {
              mentionViewModel.clearMentionState()
              Task {
                let result = await viewModel.submitComment(
                  text: viewModel.text.string
                )
                return result
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
            .disabled(
              {
                let hasImage: Bool
                if case .success = viewModel.imageState {
                  hasImage = true
                } else {
                  hasImage = false
                }
                return
                  (viewModel.text.string.trimmingCharacters(
                    in: .whitespacesAndNewlines
                  ).isEmpty
                  && !hasImage)
                  || viewModel.isSubmitting
              }()
            )
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
        }
      }
      .modify {
        if #available(iOS 26, macOS 26, *) {
          $0
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
    .sheet(item: $presentingImage) { selected in
      LocalImagePager(
        images: [selected.image],
        initialIndex: 0,
        onDismiss: { presentingImage = nil }
      )
      .modify {
        if #available(iOS 18, *) {
          $0.navigationTransition(.zoom(sourceID: "zoom", in: namespace))
        }
      }
    }
    #if os(macOS)
      .frame(maxWidth: 600)
    #endif
  }
}

#Preview {
  CommentInputView(
    viewModel: CommentsView.ViewModel(postId: 1, postManager: PostStore())
  )
}
