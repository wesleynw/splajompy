//
//  NewPostViewModel.swift
//  Splajompy
//
//  Created by Wesley Weisenberger on 4/2/25.
//

import PhotosUI
import SwiftUI

struct CreatePostRequest: Encodable {
  let content: String
  let imageIds: [String]
}

enum PhotoState {
  case loading(PhotosPickerItem)
  case loaded(UIImage)
  case failed
}

extension NewPostView {
  class ViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorDisplay: String?

    private let dismiss: () -> Void

    init(dismiss: @escaping () -> Void) {
      self.dismiss = dismiss
    }

    func submitPost(text: String) {
      Task { @MainActor in
        if text.count > 5000 {
          errorDisplay =
            "This post is \(5000 - text.count) characters too long."
          return
        }

        isLoading = true
        do {
          try await APIService.shared.requestWithoutResponse(
            endpoint: "/post/new",
            method: "POST",
            body: ["text": text]
          )
          errorDisplay = ""
          isLoading = false
          dismiss()
        } catch {
          errorDisplay = "There was an error: \(error.localizedDescription)."
          isLoading = false
        }
      }
    }
  }
}
