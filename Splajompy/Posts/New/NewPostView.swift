import PhotosUI
import PostHog
import SwiftUI

struct NewPostView: View {
  @State private var text = NSAttributedString(string: "")
  @State private var poll: PollCreationRequest?
  @State private var showingPollCreation: Bool = false
  @State private var cursorY: CGFloat = 0
  @State private var cursorPosition: Int = 0

  @StateObject private var viewModel: ViewModel
  @StateObject private var mentionViewModel =
    MentionTextEditor.MentionViewModel()
  @FocusState private var isFocused: Bool

  @Environment(\.dismiss) private var dismiss

  init(onPostCreated: @escaping () -> Void = {}) {
    _viewModel = StateObject(
      wrappedValue: ViewModel(onPostCreated: onPostCreated)
    )
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        ScrollView {
          VStack {
            MentionTextEditor(
              text: $text,
              viewModel: mentionViewModel,
              cursorY: $cursorY,
              cursorPosition: $cursorPosition,
              isCompact: false,
              autoFocusOnAppear: true
            )

            imagePreviewsView

            if let poll = poll {
              PollPreviewView(poll: poll) {
                self.poll = nil
              } onEdit: {
                showingPollCreation = true
              }
            }
          }
          // to allow mentions overlay to be visible when at bottom of text view
          .padding(.bottom, 250)
          .overlay(alignment: .topLeading) {
            if mentionViewModel.isShowingSuggestions {
              MentionTextEditor.suggestionView(
                suggestions: mentionViewModel.mentionSuggestions,
                onInsert: { user in
                  let result = mentionViewModel.insertMention(
                    user,
                    in: text,
                    at: cursorPosition
                  )
                  text = result.text
                  cursorPosition = result.newCursorPosition
                }
              )
              .offset(y: cursorY + 20)
              .padding(.horizontal, 32)
              .animation(.default, value: mentionViewModel.isShowingSuggestions)
            }
          }
        }

        Divider()

        postAdditionsMenu
      }
      .alert(
        "An error occurred",
        isPresented: .constant(viewModel.errorDisplay != nil),
        actions: {
          Button("OK") {
            viewModel.errorDisplay = nil
          }
        }
      ) {
        Text(viewModel.errorDisplay ?? "There was an error.")
      }
      .navigationTitle("New Post")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          if #available(iOS 26.0, *) {
            Button(role: .close, action: { dismiss() })
          } else {
            Button {
              dismiss()
            } label: {
              Image(systemName: "xmark.circle.fill")
                .opacity(0.8)
            }
            .buttonStyle(.plain)
          }
        }

        ToolbarItem(placement: .topBarTrailing) {
          if #available(iOS 26, *) {
            Button {
              viewModel.submitPost(
                text: String(
                  text.string.trimmingCharacters(in: .whitespacesAndNewlines)
                ),
                poll: poll,
                dismiss: { dismiss() }
              )
            } label: {
              if viewModel.isLoading {
                ProgressView()
              } else {
                Label("Post", systemImage: "arrow.up")
              }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isPostButtonDisabled)
          } else {
            Button {
              viewModel.submitPost(
                text: String(
                  text.string.trimmingCharacters(in: .whitespacesAndNewlines)
                ),
                poll: poll,
                dismiss: { dismiss() }
              )
            } label: {
              Image(systemName: "arrow.up.circle.fill")
                .opacity(0.8)
            }
            .disabled(isPostButtonDisabled)
          }
        }
      }
    }
    .sheet(isPresented: $showingPollCreation) {
      PollCreationView(poll: $poll)
    }
  }

  @ViewBuilder
  private var imagePreviewsView: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 12) {
        ForEach(viewModel.imageStates, id: \.itemIdentifier) { item in
          ZStack(alignment: .topTrailing) {
            ZStack {
              RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
                .frame(width: 100, height: 100)

              switch item.state {
              case .loading:
                ProgressView()
              case .success(let image):
                Image(uiImage: image)
                  .resizable()
                  .scaledToFill()
                  .frame(width: 100, height: 100)
                  .clipShape(RoundedRectangle(cornerRadius: 12))
              case .failure:
                Button {
                  viewModel.retryImage(itemIdentifier: item.itemIdentifier)
                } label: {
                  VStack {
                    Image(systemName: "arrow.clockwise.circle.fill")
                      .font(.title)
                      .foregroundColor(.blue)
                    Text("Retry")
                      .font(.caption2)
                      .foregroundColor(.blue)
                  }
                }
              case .empty:
                EmptyView()
              }
            }
            .overlay(
              RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )

            Button {
              viewModel.removeImage(itemIdentifier: item.itemIdentifier)
            } label: {
              ZStack {
                Circle()
                  .fill(Color.white)
                  .frame(width: 22, height: 22)
                  .shadow(
                    color: Color.black.opacity(0.2),
                    radius: 2,
                    x: 0,
                    y: 1
                  )

                Image(systemName: "xmark")
                  .font(.system(size: 10, weight: .bold))
                  .foregroundColor(.gray)
              }
            }
            .padding(6)
          }
          .padding(4)
          .transition(.scale)
        }
      }
      .padding(.horizontal)
    }
  }

  @ViewBuilder
  private var postAdditionsMenu: some View {
    HStack {
      PhotosPicker(
        selection: $viewModel.imageSelection,
        maxSelectionCount: 10,
        selectionBehavior: .ordered,
        matching: .images
      ) {
        Image(systemName: "photo.badge.plus")
          .padding(.leading)
      }

      Button {
        showingPollCreation = true
      } label: {
        Image(systemName: poll != nil ? "chart.bar.fill" : "chart.bar")
          .padding(.leading)
      }

      Spacer()

      Text("\(text.string.count)/2500")
        .foregroundStyle(
          text.string.count > 2500
            ? Color.red.opacity(0.7) : Color.primary.opacity(0.5)
        )
    }
    .padding()
  }

  private var isPostButtonDisabled: Bool {
    let trimmedText = text.string.trimmingCharacters(
      in: .whitespacesAndNewlines
    )
    let hasContent =
      !trimmedText.isEmpty || viewModel.imageStates.count > 0 || poll != nil

    let allImagesLoaded = viewModel.imageStates.allSatisfy { item in
      if case .success = item.state {
        return true
      }
      return false
    }

    return !hasContent || trimmedText.count > 2500 || viewModel.isLoading
      || !allImagesLoaded
  }
}

struct NewPostView_Previews: PreviewProvider {
  static var previews: some View {
    NewPostView()
  }
}
