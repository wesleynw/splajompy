//
//  ViewModel-PostView.swift
//  Splajompy
//
//  Created by Wesley Weisenberger on 3/25/25.
//

import Foundation

extension CommentsView {
  @MainActor class ViewModel: ObservableObject {
    private let postId: Int

    @Published var comments = [Comment]()
    @Published var isLoading = true

    init(postId: Int) {
      self.postId = postId
      loadComments()
    }

    func loadComments() {
      Task {
        isLoading = true
        do {
          comments = try await APIService.shared.request(
            endpoint: "/post/\(postId)/comments", method: "GET")
        } catch {
          print("error fetching comments: \(error.localizedDescription)")
        }
        isLoading = false
      }
    }

    func toggleLike(for comment: Comment) {
      Task {
        let method = comment.isLiked ? "DELETE" : "POST"

        do {
          try await APIService.shared.requestWithoutResponse(
            endpoint: "/post/\(comment.postId)/comment/\(comment.commentId)/liked", method: method)
        } catch {
          print("error adding like to post: \(error.localizedDescription)")
        }
        if let index = comments.firstIndex(where: { $0.commentId == comment.commentId }) {
          comments[index].isLiked.toggle()
        }
        // TODO: update parent viewModel with comment count
      }
    }

    func addComment(text: String) {
      Task {
        do {
          let newComment: Comment = try await APIService.shared.request(
            endpoint: "/post/\(postId)/comment", method: "POST", body: ["Text": text])
          comments.append(newComment)
          // TODO: update comment count in parent VM
        } catch {
          print("Error adding like to post: \(error.localizedDescription)")
        }
      }
    }
  }
}
