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

@MainActor @Observable final class ImageEntry: Identifiable {
  let id: String
  var pickerItem: PhotosPickerItem?
  var state: ImageUploadState
  @ObservationIgnored var task: Task<Void, Never>?

  init(id: String, pickerItem: PhotosPickerItem? = nil, state: ImageUploadState) {
    self.id = id
    self.pickerItem = pickerItem
    self.state = state
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

    var imageStates: [ImageEntry] = []
    var imageSelection = [PhotosPickerItem]() {
      didSet {
        let removedEntries = imageStates.filter { entry in
          guard let pickerItem = entry.pickerItem else { return false }
          return !imageSelection.contains(pickerItem)
        }
        for entry in removedEntries {
          entry.task?.cancel()
          entry.task = nil
        }
        imageStates = imageStates.filter { entry in
          guard let pickerItem = entry.pickerItem else { return true }
          return imageSelection.contains(pickerItem)
        }
        let existingPickerItems = imageStates.compactMap { $0.pickerItem }
        for item in imageSelection where !existingPickerItems.contains(item) {
          let itemId = item.itemIdentifier ?? UUID().uuidString
          let entry = ImageEntry(id: itemId, pickerItem: item, state: .empty)
          imageStates.append(entry)
          beginProcessing(entry: entry, source: .pickerItem(item))
        }
      }
    }

    private let onPostCreated: () -> Void
    private let stagingFolder = UUID()

    init(onPostCreated: @escaping () -> Void) {
      self.onPostCreated = onPostCreated
    }

    func removeImage(_ entry: ImageEntry) {
      entry.task?.cancel()
      entry.task = nil

      guard
        let pickerItem = entry.pickerItem,
        let index = imageSelection.firstIndex(where: { $0 == pickerItem })
      else {
        withAnimation(.snappy) {
          imageStates.removeAll { $0.id == entry.id }
        }
        return
      }
      _ = withAnimation(.snappy) {
        imageSelection.remove(at: index)
      }
    }

    func retryImage(_ entry: ImageEntry) {
      guard let pickerItem = entry.pickerItem else { return }
      beginProcessing(entry: entry, source: .pickerItem(pickerItem))
    }

    func retryUpload(_ entry: ImageEntry) {
      guard case .uploadFailed(let image) = entry.state else { return }
      beginProcessing(entry: entry, source: .image(image))
    }

    func addDroppedImages(_ images: [PlatformImage]) {
      let remaining = max(0, 10 - imageStates.count)
      guard remaining > 0 else { return }
      let newImages = Array(images.prefix(remaining))
      let newEntries = newImages.map { image in
        ImageEntry(id: UUID().uuidString, state: .uploading(image))
      }
      withAnimation(.snappy) {
        imageStates.append(contentsOf: newEntries)
      }
      for (entry, image) in zip(newEntries, newImages) {
        beginProcessing(entry: entry, source: .image(image))
      }
    }

    private enum ImageSource {
      case pickerItem(PhotosPickerItem)
      case image(PlatformImage)
    }

    private func beginProcessing(entry: ImageEntry, source: ImageSource) {
      entry.task?.cancel()
      switch source {
      case .pickerItem: entry.state = .loadingPhoto
      case .image(let image): entry.state = .uploading(image)
      }

      entry.task = Task {
        let image: PlatformImage
        switch source {
        case .image(let sourceImage):
          image = sourceImage
        case .pickerItem(let item):
          guard let loaded = await self.loadImage(from: item, entry: entry) else { return }
          image = loaded
          entry.state = .uploading(image)
        }

        guard !Task.isCancelled else { return }
        let imageData = await uploadImageData(image, folder: self.stagingFolder)
        guard !Task.isCancelled else { return }
        entry.state = if let imageData { .uploaded(image, imageData) } else { .uploadFailed(image) }
      }
    }

    private func loadImage(from item: PhotosPickerItem, entry: ImageEntry) async -> PlatformImage? {
      let data: Data?
      do {
        data = try await item.loadTransferable(type: Data.self)
      } catch {
        guard !Task.isCancelled else { return nil }
        entry.state = .photoFailed
        return nil
      }
      guard !Task.isCancelled else { return nil }
      guard let data, let image = PlatformImage(data: data) else {
        entry.state = data == nil ? .empty : .photoFailed
        return nil
      }
      return image
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

        for entry in imageStates {
          await entry.task?.value
        }

        guard imageStates.allSatisfy({ $0.state.isUploaded }) else {
          errorDisplay =
            "One or more images failed to upload. Please retry or remove them before posting."
          isLoading = false
          return
        }

        var imageKeymap: [Int: ImageData] = [:]
        for (index, entry) in imageStates.enumerated() {
          if case .uploaded(_, let data) = entry.state {
            imageKeymap[index] = data
          }
        }

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
  }
}
