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
  case success(UIImage)
  case failed
  case empty
}

extension NewPostView {
  class ViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorDisplay: String?

    @Published var imageSelection: PhotosPickerItem? = nil {
      didSet {
        if let imageSelection = imageSelection {
          photoState = .loading(imageSelection)
          _ = loadTransferable(from: imageSelection)
        } else {
          photoState = .empty
        }
      }
    }
    @Published var photoState: PhotoState?

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

    private func loadTransferable(from imageSelection: PhotosPickerItem)
      -> Progress
    {
      return imageSelection.loadTransferable(type: Data.self) { result in
        DispatchQueue.main.async {
          guard imageSelection == self.imageSelection else {
            print("Failed to get the selected item.")
            return
          }

          switch result {
          case .success(let imageData?):
            if let uiImage = UIImage(data: imageData) {
              self.photoState = .success(uiImage)
            } else {
              self.photoState = .failed
            }
          case .success(nil):
            self.photoState = .empty
          case .failure(_):
            self.photoState = .failed
          }
        }
      }
    }

  }
}
