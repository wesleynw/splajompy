import PhotosUI
import SwiftUI

enum PhotoState {
  case loading(Progress)
  case success(UIImage)
  case failure
  case empty
}

extension NewPostView {
  @MainActor @Observable class ViewModel {
    var isLoading = false
    var errorDisplay: String?

    var text: NSAttributedString = NSAttributedString(string: "")
    var selectedRange: NSRange = NSRange(location: 0, length: 0)
    var poll: PollCreationRequest?
    var visibility: VisibilityType = .Public

    var imageStates = [
      (itemIdentifier: String, pickerItem: PhotosPickerItem, state: PhotoState)
    ]()
    var imageSelection = [PhotosPickerItem]() {
      didSet {
        let oldStates = imageStates
        imageStates = imageSelection.map { item in
          let itemId = item.itemIdentifier ?? UUID().uuidString
          if let existingState = oldStates.first(where: {
            $0.pickerItem == item
          }) {
            return (
              itemIdentifier: existingState.itemIdentifier, pickerItem: item,
              state: existingState.state
            )
          } else {
            return (
              itemIdentifier: itemId, pickerItem: item,
              state: .loading(loadTransferable(from: item, itemId: itemId))
            )
          }
        }
      }
    }

    private let onPostCreated: () -> Void

    init(onPostCreated: @escaping () -> Void) {
      self.onPostCreated = onPostCreated
    }

    func removeImage(itemIdentifier: String) {
      guard
        let pickerItem = imageStates.first(where: {
          $0.itemIdentifier == itemIdentifier
        })?.pickerItem,
        let index = imageSelection.firstIndex(where: { $0 == pickerItem })
      else {
        return
      }
      _ = withAnimation(.snappy) {
        imageSelection.remove(at: index)
      }
    }

    func retryImage(itemIdentifier: String) {
      guard
        let index = imageStates.firstIndex(where: {
          $0.itemIdentifier == itemIdentifier
        })
      else {
        return
      }
      let pickerItem = imageStates[index].pickerItem
      imageStates[index].state = .loading(
        loadTransferable(from: pickerItem, itemId: itemIdentifier)
      )
    }

    func submitPost(
      text: String,
      poll: PollCreationRequest? = nil,
      dismiss: @escaping () -> Void
    ) {
      Task {
        let validation = PostCreationService.validatePostText(text: text)
        if !validation.isValid {
          errorDisplay = validation.errorMessage
          return
        }

        isLoading = true

        let selectedImages = imageStates.compactMap { item -> UIImage? in
          if case .success(let image) = item.state {
            return image
          }
          return nil
        }

        let result = await PostCreationService.createPost(
          text: text,
          images: selectedImages,
          items: imageSelection,
          visibility: visibility,
          poll: poll
        )

        switch result {
        case .success:
          isLoading = false
          onPostCreated()
          dismiss()
        case .error(let error):
          errorDisplay = error.localizedDescription
          isLoading = false
        }
      }
    }

    func resetInputState() {
      text = NSAttributedString(string: "")
      selectedRange = NSRange(location: 0, length: 0)
      poll = nil
    }

    private func loadTransferable(
      from imageSelection: PhotosPickerItem,
      itemId: String
    ) -> Progress {
      return imageSelection.loadTransferable(type: Data.self) { result in
        DispatchQueue.main.async {
          guard
            let index = self.imageStates.firstIndex(where: {
              $0.itemIdentifier == itemId
            })
          else {
            print("Failed to find the item in imageStates.")
            return
          }
          switch result {
          case .success(let imageData?):
            if let image = UIImage(data: imageData) {
              self.imageStates[index].state = .success(image)
            } else {
              self.imageStates[index].state = .failure
            }
          case .success(nil):
            self.imageStates[index].state = .empty
          case .failure(_):
            self.imageStates[index].state = .failure
          }
        }
      }
    }
  }
}
