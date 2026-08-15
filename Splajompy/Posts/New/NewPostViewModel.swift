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

extension NewPostView {
  @MainActor @Observable class ViewModel {
    var isLoading = false
    var errorDisplay: String?

    var text: NSAttributedString = NSAttributedString(string: "")
    var selectedRange: NSRange = NSRange(location: 0, length: 0)
    var poll: PollCreationRequest?
    var visibility: VisibilityType = .everyone

    var imageStates = [
      (
        itemIdentifier: String, pickerItem: PhotosPickerItem?, state: PhotoState,
        uploadState: UploadState
      )
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
              state: .loading(loadTransferable(from: item, itemId: itemId)),
              uploadState: .pending
            )
          )
        }
      }
    }

    private let onPostCreated: () -> Void
    private let stagingFolder = UUID()
    private var uploadTasks: [String: Task<Void, Never>] = [:]

    init(onPostCreated: @escaping () -> Void) {
      self.onPostCreated = onPostCreated
    }

    func removeImage(itemIdentifier: String) {
      uploadTasks[itemIdentifier]?.cancel()
      uploadTasks[itemIdentifier] = nil

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

    func retryUpload(itemIdentifier: String) {
      guard
        let index = imageStates.firstIndex(where: {
          $0.itemIdentifier == itemIdentifier
        }),
        case .success(let image) = imageStates[index].state
      else {
        return
      }
      startUpload(itemIdentifier: itemIdentifier, image: image)
    }

    func addDroppedImages(_ images: [PlatformImage]) {
      let remaining = max(0, 10 - imageStates.count)
      guard remaining > 0 else { return }
      let newImages = Array(images.prefix(remaining))
      let identifiers = newImages.map { _ in UUID().uuidString }
      withAnimation(.snappy) {
        imageStates.append(
          contentsOf: zip(identifiers, newImages).map { itemIdentifier, image in
            (
              itemIdentifier: itemIdentifier, pickerItem: nil,
              state: .success(image), uploadState: .pending
            )
          }
        )
      }
      for (itemIdentifier, image) in zip(identifiers, newImages) {
        startUpload(itemIdentifier: itemIdentifier, image: image)
      }
    }

    private func startUpload(itemIdentifier: String, image: PlatformImage) {
      guard
        let index = imageStates.firstIndex(where: {
          $0.itemIdentifier == itemIdentifier
        })
      else {
        return
      }

      imageStates[index].uploadState = .pending

      let folder = stagingFolder
      uploadTasks[itemIdentifier] = Task {
        let result = await uploadImageState(image, folder: folder)
        guard !Task.isCancelled else { return }
        if let idx = self.imageStates.firstIndex(where: {
          $0.itemIdentifier == itemIdentifier
        }) {
          self.imageStates[idx].uploadState = result
        }
        self.uploadTasks[itemIdentifier] = nil
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

        let imageKeymap: [Int: ImageData] = Dictionary(
          uniqueKeysWithValues: imageStates.enumerated().compactMap {
            index, item -> (Int, ImageData)? in
            if case .uploaded(let data) = item.uploadState {
              return (index, data)
            }
            return nil
          }
        )

        let result = await PostCreationService.createPost(
          text: text,
          imageKeymap: imageKeymap,
          visibility: visibility,
          poll: poll
        )

        switch result {
        case .success:
          isLoading = false
          PostHogSDK.shared.capture("post_created")
          onPostCreated()
          dismiss()
        case .failure(let error):
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
              self.startUpload(itemIdentifier: itemId, image: image)
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
