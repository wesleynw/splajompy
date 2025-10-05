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
              cursorPosition: $cursorPosition
            )

            ScrollView(.horizontal, showsIndicators: false) {
              HStack(spacing: 12) {
                ForEach(0..<viewModel.selectedImages.count, id: \.self) { i in
                  ZStack(alignment: .topTrailing) {
                    Image(uiImage: viewModel.selectedImages[i])
                      .resizable()
                      .scaledToFill()
                      .frame(width: 100, height: 100)
                      .clipShape(RoundedRectangle(cornerRadius: 12))
                      .overlay(
                        RoundedRectangle(cornerRadius: 12)
                          .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                      )

                    Button {
                      viewModel.removeImage(index: i)
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
                }
              }
              .padding(.horizontal)
            }

            if let poll = poll {
              PollPreviewView(poll: poll) {
                self.poll = nil
              } onEdit: {
                showingPollCreation = true
              }
            }
          }
          .padding(.bottom, 250)  // to allow mentions overlay to be visible when at bottom of text view
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

        HStack {
          PhotosPicker(
            selection: $viewModel.selectedItems,
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

  private var isPostButtonDisabled: Bool {
    let trimmedText = text.string.trimmingCharacters(
      in: .whitespacesAndNewlines
    )
    let hasContent =
      !trimmedText.isEmpty || viewModel.selectedImages.count > 0 || poll != nil

    return !hasContent || trimmedText.count > 2500 || viewModel.isLoading
  }
}

struct NewPostView_Previews: PreviewProvider {
  static var previews: some View {
    NewPostView()
  }
}
