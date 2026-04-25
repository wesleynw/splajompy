import Nuke
import PhotosUI
import SwiftUI

enum DownloadState {
  case idle, downloading, done, error

  var iconName: String {
    switch self {
    case .idle, .downloading: "arrow.down.to.line"
    case .done: "checkmark"
    case .error: "exclamationmark.triangle"
    }
  }
}

@MainActor @Observable
class PhotoSaveViewModel {
  var downloadState: DownloadState = .idle
  var shouldShowPermissionsPrompt: Bool = false

  func saveImageToPhotoLibrary(urlString: String) async {
    let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
    guard status != .denied else {
      shouldShowPermissionsPrompt = true
      return
    }

    guard let url = URL(string: urlString) else {
      downloadState = .error
      return
    }

    downloadState = .downloading

    guard let image = try? await ImagePipeline.shared.image(for: url) else {
      downloadState = .error
      return
    }

    let success = await performImageSave(image: image)
    self.downloadState = success ? .done : .error
  }

  // this is kind of a hack, as this code seems to crash when it's on the main thread for some reason
  // https://stackoverflow.com/questions/79793025/phphotolibrary-shared-performchanges-crashes-when-trying-to-save-image-to-phot
  nonisolated func performImageSave(image: UIImage) async -> Bool {
    do {
      try await PHPhotoLibrary.shared().performChanges {
        PHAssetChangeRequest.creationRequestForAsset(from: image)
      }
      return true
    } catch {
      print("Error saving to photo library: \(error)")
      return false
    }
  }
}
