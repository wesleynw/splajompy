import SwiftUI

struct PostActionMenu<MenuLabel: View>: View {
  let post: ObservablePost?
  var showAuthor: Bool
  var onPostDeleted: () -> Void
  var onPostPinned: () -> Void
  var onPostUnpinned: () -> Void
  @ViewBuilder var label: () -> MenuLabel

  @State private var isReporting = false
  @State private var showReportAlert = false
  @State private var showDeleteConfirmation = false
  @Environment(AuthManager.self) private var authManager

  var body: some View {
    Menu {
      if let post, let currentUser = authManager.getCurrentUser() {
        if currentUser.userId == post.user.userId {
          if !showAuthor {
            if post.isPinned {
              Button(action: {
                onPostUnpinned()
              }) {
                Label("Unpin", systemImage: "pin.slash")
              }
            } else {
              Button(action: {
                onPostPinned()
              }) {
                Label("Pin", systemImage: "pin")
              }
            }
          }

          Button(
            role: .destructive,
            action: { showDeleteConfirmation = true }
          ) {
            Label("Delete", systemImage: "trash")
              .foregroundColor(.red)
          }
        } else {
          Button(
            role: .destructive,
            action: {
              Task {
                isReporting = true
                let _ = await PostService().reportPost(
                  postId: post.post.postId
                )
                isReporting = false
                showReportAlert = true
              }
            }
          ) {
            if isReporting {
              HStack {
                Text("Reporting...")
                Spacer()
                ProgressView()
              }
            } else {
              Label("Report", systemImage: "exclamationmark.triangle")
                .foregroundColor(.red)
            }
          }
          .disabled(isReporting)
        }
      }
    } label: {
      label()
    }
    .disabled(post == nil)
    .alert("Post Reported", isPresented: $showReportAlert) {
      Button("OK") {}
    } message: {
      Text("Thanks. A notification has been sent to the developer.")
    }
    .confirmationDialog(
      "Are you sure you want to delete this post?",
      isPresented: $showDeleteConfirmation,
      titleVisibility: .visible
    ) {
      Button("Delete", role: .destructive) {
        onPostDeleted()
      }
      Button("Cancel", role: .cancel) {}
    }
  }
}
