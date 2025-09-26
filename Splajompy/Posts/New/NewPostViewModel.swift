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

    @Published var selectedImages = [UIImage]()
    // TODO: find a way to do this without resetting the entire array of selected images
    @Published var selectedItems = [PhotosPickerItem]() {
      didSet {
        Task {
          var newImages = [UIImage]()

          for item in selectedItems {
            if let data = try? await item.loadTransferable(type: Data.self) {
              if let uiImage = UIImage(data: data) {
                print("Original image size: \(uiImage.size)")
                if let resizedImage = uiImage.resize(newWidth: 1000) {
                  print("Resized image size: \(resizedImage.size)")
                  newImages.append(resizedImage)
                } else {
                  print("Resize failed")
                }
              }
            }
          }

          selectedImages = newImages
        }
      }
    }

    private let onPostCreated: () -> Void

    init(onPostCreated: @escaping () -> Void) {
      self.onPostCreated = onPostCreated
    }

    func removeImage(index: Int) {
      selectedItems.remove(at: index)
    }

    func submitPost(text: String, poll: PollCreationRequest? = nil, dismiss: @escaping () -> Void) {
      print("🚀 submitPost called with text: '\(text)' poll: \(poll != nil)")
      Task {
        print("📝 Starting post validation...")
        let validation = PostCreationService.validatePostText(text: text)
        if !validation.isValid {
          print("❌ Validation failed: \(validation.errorMessage ?? "unknown error")")
          errorDisplay = validation.errorMessage
          return
        }

        print("✅ Validation passed, setting loading state...")
        isLoading = true

        let result: AsyncResult<EmptyResponse>

        print("📤 Calling PostCreationService.createPost...")
        result = await PostCreationService.createPost(
          text: text, images: selectedImages, items: selectedItems, poll: poll)

        print("📥 Got result from PostCreationService: \(result)")

        switch result {
        case .success:
          print("✅ Post creation successful!")
          errorDisplay = ""
          isLoading = false
          onPostCreated()
          dismiss()
        case .error(let error):
          print("❌ Post creation failed: \(error.localizedDescription)")
          errorDisplay = "There was an error: \(error.localizedDescription)."
          isLoading = false
        }
      }
    }
  }
}
