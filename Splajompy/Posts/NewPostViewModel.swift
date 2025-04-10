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
        private let onPostCreated: () -> Void

        init(dismiss: @escaping () -> Void, onPostCreated: @escaping () -> Void) {
            self.dismiss = dismiss
            self.onPostCreated = onPostCreated
        }

        func submitPost(text: String) {
            Task {
                // Validate the post text
                let validation = PostCreationService.validatePostText(text: text)
                if !validation.isValid {
                    errorDisplay = validation.errorMessage
                    return
                }

                isLoading = true
                
                let result: APIResult<Void>
                
//                if case .success(let image) = photoState {
//                  print("todo")
//                  result = .failure(new Error("not implemented"))
////                    result = await PostCreationService.createPostWithImage(text: text, image: image)
//                } else {
                    result = await PostCreationService.createPost(text: text)
//                }
                
                switch result {
                case .success:
                    errorDisplay = ""
                    isLoading = false
                    onPostCreated()
                    dismiss()
                case .failure(let error):
                    errorDisplay = "There was an error: \(error.localizedDescription)."
                    isLoading = false
                }
            }
        }

        private func loadTransferable(from imageSelection: PhotosPickerItem) -> Progress {
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
