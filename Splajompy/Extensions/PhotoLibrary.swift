import Nuke
import PhotosUI
import SwiftUI

enum DownloadState {
  case idle, downloading, done, error
}

@MainActor @Observable
class PhotoSaveViewModel {
  var downloadState: DownloadState = .idle
  var shouldShowPermissionsPrompt: Bool = false

  func saveImageToPhotoLibrary(urlString: String) async {
    let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
    guard status == .authorized || status == .limited else {
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

    do {
      try await PHPhotoLibrary.shared().performChanges {
        PHAssetChangeRequest.creationRequestForAsset(from: image)
      }
      downloadState = .done
    } catch {
      print("Error saving to photo library: \(error)")
      downloadState = .error
    }
  }
}
