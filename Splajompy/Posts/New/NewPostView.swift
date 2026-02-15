import PhotosUI
import PostHog
import SwiftUI

struct NewPostView: View {
  @State private var cursorY: CGFloat = 0
  @State private var showingPollCreation: Bool = false

  @State private var viewModel: ViewModel
  @State private var mentionViewModel =
    MentionTextEditor.MentionViewModel()

  @Environment(\.dismiss) private var dismiss

  init(onPostCreated: @escaping () -> Void = {}) {
    _viewModel = State(
      wrappedValue: ViewModel(onPostCreated: onPostCreated)
    )
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        ScrollView {
          VStack {
            MentionTextEditor(
              text: $viewModel.text,
              viewModel: mentionViewModel,
              cursorY: $cursorY,
              selectedRange: $viewModel.selectedRange,
              isCompact: false,
              autoFocusOnAppear: true
            )

            imagePreviewsView

            if let poll = viewModel.poll {
              PollPreviewView(poll: poll) {
                viewModel.poll = nil
              } onEdit: {
                showingPollCreation.toggle()
              }
            }
          }
          // to allow mentions overlay to be visible when at bottom of text view
          .padding(.bottom, 250)
          .overlay(alignment: .topLeading) {
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
              .offset(y: cursorY + 40)
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
        isPresented: Binding(
          get: { viewModel.errorDisplay != nil },
          set: { if !$0 { viewModel.errorDisplay = nil } }
        ),
        actions: {
          Button("OK") {
            viewModel.errorDisplay = nil
          }
        }
      ) {
        Text(viewModel.errorDisplay ?? "There was an error.")
      }
      .navigationTitle("New Post")
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        #if os(iOS)
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
        #else
          ToolbarItem(placement: .cancellationAction) {
            if #available(macOS 26.0, *) {
              Button(role: .cancel, action: { dismiss() })
            } else {
              Button {
                dismiss()
              } label: {
                Label("Cancel", systemImage: "xmark.circle.fill")
              }
              .buttonStyle(.plain)
            }
          }
        #endif

        #if os(iOS)
          ToolbarItem(placement: .topBarTrailing) {
            if #available(iOS 26, *) {
              Button(action: submitPostAction) {
                if viewModel.isLoading {
                  ProgressView()
                } else {
                  Label("Post", systemImage: "arrow.up")
                }
              }
              .buttonStyle(.borderedProminent)
              .disabled(isPostButtonDisabled)
            } else {
              if viewModel.isLoading {
                ProgressView()
              } else {
                Button(action: submitPostAction) {
                  Image(systemName: "arrow.up.circle.fill")
                    .opacity(0.8)
                }
                .disabled(isPostButtonDisabled)
              }
            }
          }
        #else
          ToolbarItem(placement: .confirmationAction) {
            if #available(macOS 26, *) {
              Button(action: submitPostAction) {
                if viewModel.isLoading {
                  ProgressView()
                    .controlSize(.small)
                } else {
                  Label("Post", systemImage: "arrow.up")
                }
              }
              .buttonStyle(.borderedProminent)
              .disabled(isPostButtonDisabled)
            } else {
              if viewModel.isLoading {
                ProgressView()
                  .controlSize(.small)
              } else {
                Button(action: submitPostAction) {
                  Image(systemName: "arrow.up.circle.fill")
                    .opacity(0.8)
                }
                .disabled(isPostButtonDisabled)
              }
            }
          }
        #endif
      }
    }
    #if os(macOS)
      .frame(width: 500, height: 450)
    #endif
    .sheet(isPresented: $showingPollCreation) {
      PollCreationView(poll: $viewModel.poll)
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
                  #if os(macOS)
                    .controlSize(.small)
                  #endif
              case .success(let image):
                Image(platformImage: image)
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
                .buttonStyle(.plain)
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
            .buttonStyle(.plain)
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
      .buttonStyle(.plain)

      Button {
        showingPollCreation.toggle()
      } label: {
        Image(
          systemName: viewModel.poll != nil ? "chart.bar.fill" : "chart.bar"
        )
        .padding(.leading)
      }
      .buttonStyle(.plain)

      Spacer()

      if PostHogSDK.shared.isFeatureEnabled("post-visibility-toggle") {
        PostVisibilityToggle(selectedVisibility: $viewModel.visibility)
      }

      Text("\(viewModel.text.string.count)/2500")
        .monospacedDigit()
        .foregroundStyle(
          viewModel.text.string.count > 2500
            ? Color.red.opacity(0.7) : Color.primary.opacity(0.5)
        )
    }
    .padding()
  }

  private var isPostButtonDisabled: Bool {
    let trimmedText = viewModel.text.string.trimmingCharacters(
      in: .whitespacesAndNewlines
    )
    let hasContent =
      !trimmedText.isEmpty || viewModel.imageStates.count > 0
      || viewModel.poll != nil

    let allImagesLoaded = viewModel.imageStates.allSatisfy { item in
      if case .success = item.state {
        return true
      }
      return false
    }

    return !hasContent || trimmedText.count > 2500 || viewModel.isLoading
      || !allImagesLoaded
  }

  private func submitPostAction() {
    viewModel.submitPost(
      text: String(
        viewModel.text.string.trimmingCharacters(in: .whitespacesAndNewlines)
      ),
      poll: viewModel.poll,
      dismiss: { dismiss() }
    )
  }
}

struct NewPostView_Previews: PreviewProvider {
  static var previews: some View {
    NewPostView()
  }
}
