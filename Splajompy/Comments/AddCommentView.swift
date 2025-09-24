import SwiftUI

struct AddCommentSheet: View {
  @ObservedObject var viewModel: CommentsView.ViewModel
  @State private var text = NSAttributedString(string: "")
  @Environment(\.dismiss) var dismiss
  let postId: Int
  let postManager: PostManager

  var body: some View {
    NavigationStack {
      VStack(spacing: 12) {
        #if os(iOS)
          MentionTextEditor(text: $text, showSuggestionsOnTop: false)
        #endif

        Spacer()
      }
      .alert(isPresented: $viewModel.showError) {
        Alert(
          title: Text("Error"),
          message: Text(viewModel.errorMessage ?? "Unknown error"),
          dismissButton: .default(Text("OK")) {
            viewModel.showError = false
          }
        )
      }
      .navigationTitle("Comment")
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
              Task {
                let result = await viewModel.submitComment(text: text.string)
                if result == true {
                  dismiss()
                }
              }
            } label: {
              if viewModel.isLoading {
                ProgressView()
              } else {
                Image(systemName: "arrow.up")
              }
            }
            .disabled(
              text.string.trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty
                || viewModel.isLoading
            )
            .buttonStyle(.glassProminent)
          } else {
            Button {
              Task {
                let result = await viewModel.submitComment(text: text.string)
                if result == true {
                  dismiss()
                }
              }
            } label: {
              Image(systemName: "arrow.up.circle.fill")
                .opacity(0.8)
            }
            .disabled(
              text.string.trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty
                || viewModel.isLoading
            )
          }
        }
      }
    }
  }
}

#Preview {
  @Previewable @State var showSheet = true

  Color.clear
    .sheet(isPresented: .constant(true)) {
      AddCommentSheet(
        viewModel: CommentsView.ViewModel(
          postId: 1,
          postManager: PostManager()
        ),
        postId: 1,
        postManager: PostManager()
      )
    }
}
