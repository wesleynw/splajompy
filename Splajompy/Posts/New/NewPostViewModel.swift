import Foundation
import PhotosUI
import SwiftUI

enum PhotoState {
  case loading(PhotosPickerItem)
  case success(UIImage)
  case failed
  case empty
}

extension NewPostView {
  @MainActor class ViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorDisplay: String?

    @Published var selectedImages = [Image]()
    // TODO: find a way to do this without resetting the entire array of selected images
    @Published var selectedItems = [PhotosPickerItem]() {
      didSet {
        Task {
          var newImages = [Image]()

          for item in selectedItems {
            if let image = try? await item.loadTransferable(type: Image.self) {
              newImages.append(image)
            }
          }

          selectedImages = newImages
        }
      }
    }

    private let dismiss: () -> Void
    private let onPostCreated: () -> Void

    init(dismiss: @escaping () -> Void, onPostCreated: @escaping () -> Void) {
      self.dismiss = dismiss
      self.onPostCreated = onPostCreated
    }

    func removeImage(index: Int) {
      selectedItems.remove(at: index)
    }

    func submitPost(text: String) {
      Task {
        let validation = PostCreationService.validatePostText(text: text)
        if !validation.isValid {
          errorDisplay = validation.errorMessage
          return
        }

        isLoading = true

        let result: AsyncResult<EmptyResponse>

        result = await PostCreationService.createPost(
          text: text, images: selectedImages, items: selectedItems)

        switch result {
        case .success:
          errorDisplay = ""
          isLoading = false
          onPostCreated()
          dismiss()
        case .error(let error):
          errorDisplay = "There was an error: \(error.localizedDescription)."
          isLoading = false
        }
      }
    }
  }
}
