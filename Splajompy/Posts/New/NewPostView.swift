import PhotosUI
import PostHog
import SwiftUI

struct NewPostView: View {
  @State private var cursorY: CGFloat = 0
  @State private var showingPollCreation: Bool = false
  @State private var isDragTargeted: Bool = false

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
              isEditingEnabled: !viewModel.isLoading,
              isCompact: false,
              autoFocusOnAppear: true
            )
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
                .offset(y: cursorY + 10)
                .padding(.horizontal)
                .animation(
                  .default,
                  value: mentionViewModel.isShowingSuggestions
                )
              }
            }
            .padding()

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
        }
        .dropDestination(for: DroppedImage.self) { dropped, _ in
          viewModel.addDroppedImages(dropped.map { $0.image })
          return !dropped.isEmpty
        } isTargeted: {
          isDragTargeted = $0
        }
        .overlay {
          if isDragTargeted {
            RoundedRectangle(cornerRadius: 12)
              .strokeBorder(.tint.opacity(0.6), lineWidth: 2)
              .background(
                RoundedRectangle(cornerRadius: 12)
                  .fill(.tint.opacity(0.08))
              )
              .padding(4)
              .allowsHitTesting(false)
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
      .navigationTitle("New Jomp")
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
    .sensoryFeedback(.error, trigger: viewModel.errorDisplay) {
      _,
      newValue in newValue != nil
    }
    .sheet(isPresented: $showingPollCreation) {
      PollCreationView(poll: $viewModel.poll)
        .postHogScreenView()
    }
    #if os(macOS)
      .frame(width: 500, height: 450)
    #endif
  }

  var imagePreviewsView: some View {
    ScrollView(.horizontal) {
      HStack(spacing: 12) {
        ForEach(viewModel.imageStates, id: \.itemIdentifier) { item in
          ImagePreviewView(
            state: item.state,
            onRetry: {
              viewModel.retryImage(itemIdentifier: item.itemIdentifier)
            },
            onRemove: {
              viewModel.removeImage(itemIdentifier: item.itemIdentifier)
            }
          )
        }
      }
      .padding(.horizontal)
    }
    .scrollIndicators(.hidden)
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

#Preview {
  NewPostView()
    .environment(AuthManager())
}
