import PhotosUI
import PostHog
import SwiftUI
import UniformTypeIdentifiers

struct DroppedImage: Transferable {
  let image: PlatformImage

  static var transferRepresentation: some TransferRepresentation {
    DataRepresentation(importedContentType: .image) { data in
      guard let image = PlatformImage(data: data) else {
        throw CocoaError(.fileReadCorruptFile)
      }
      return DroppedImage(image: image)
    }
  }
}

enum PhotoState: Equatable {
  case loading(Progress)
  case success(PlatformImage)
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
    var visibility: VisibilityType = .everyone

    var imageStates = [
      (itemIdentifier: String, pickerItem: PhotosPickerItem?, state: PhotoState)
    ]()
    var imageSelection = [PhotosPickerItem]() {
      didSet {
        imageStates = imageStates.filter { entry in
          guard let pickerItem = entry.pickerItem else { return true }
          return imageSelection.contains(pickerItem)
        }
        let existingPickerItems = imageStates.compactMap { $0.pickerItem }
        for item in imageSelection where !existingPickerItems.contains(item) {
          let itemId = item.itemIdentifier ?? UUID().uuidString
          imageStates.append(
            (
              itemIdentifier: itemId, pickerItem: Optional(item),
              state: .loading(loadTransferable(from: item, itemId: itemId))
            ))
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
        withAnimation(.snappy) {
          imageStates.removeAll { $0.itemIdentifier == itemIdentifier }
        }
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
        }),
        let pickerItem = imageStates[index].pickerItem
      else {
        return
      }
      imageStates[index].state = .loading(
        loadTransferable(from: pickerItem, itemId: itemIdentifier)
      )
    }

    func addDroppedImages(_ images: [PlatformImage]) {
      let remaining = max(0, 10 - imageStates.count)
      guard remaining > 0 else { return }
      withAnimation(.snappy) {
        imageStates.append(
          contentsOf: images.prefix(remaining).map { image in
            (itemIdentifier: UUID().uuidString, pickerItem: nil, state: .success(image))
          }
        )
      }
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

        let selectedImages = imageStates.compactMap { item -> PlatformImage? in
          if case .success(let image) = item.state {
            return image
          }
          return nil
        }

        let result = await PostCreationService.createPost(
          text: text,
          images: selectedImages,
          visibility: visibility,
          poll: poll
        )

        switch result {
        case .success:
          isLoading = false
          PostHogSDK.shared.capture("post_created")
          onPostCreated()
          dismiss()
        case .error(let error):
          errorDisplay = error.localizedDescription
          isLoading = false
          PostHogSDK.shared.capture(
            "post_creation_failed",
            properties: ["reason": String(describing: error)]
          )
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
            if let image = PlatformImage(data: imageData) {
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
