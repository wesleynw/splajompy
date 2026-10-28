import PhotosUI
import PostHog
import SwiftUI

enum CommentState {
  case idle
  case loading
  case loaded([DetailedComment])
  case failed(Error)
}

extension CommentsContainerView {
  @MainActor @Observable class ViewModel {
    private let postId: Int
    private var service: CommentServiceProtocol

    private(set) var respondingToComment: DetailedComment?

    var commentSortOrder: String {
      get {
        UserDefaults.standard.string(forKey: "comment_sort_order")
          ?? "Newest First"
      }
      set {
        UserDefaults.standard.set(
          newValue,
          forKey: "comment_sort_order"
        )
      }
    }

    var state: CommentState = .idle
    private(set) var isSubmitting: Bool = false {
      didSet { print("isSubmitting ->", isSubmitting) }
    }
    var showError: Bool = false
    var errorMessage: String?
    var postManager: PostStore

    var pendingScrollCommentId: Int?

    var text: NSAttributedString = NSAttributedString(string: "")

    var imageSelection: PhotosPickerItem? = nil {
      didSet {
        cancelUpload()
        if let imageSelection {
          loadAndUpload(item: imageSelection)
        } else {
          imageState = .empty
        }
      }
    }
    var imageState: ImageUploadState = .empty

    var selectedRange: NSRange = NSRange(location: 0, length: 0)

    private let stagingFolder = UUID()
    private var uploadTask: Task<Void, Never>?

    init(
      postId: Int,
      service: CommentServiceProtocol = CommentService(),
      postManager: PostStore
    ) {
      self.postId = postId
      self.service = service
      self.postManager = postManager
      loadComments()
    }

    func loadComments(useLoadingState: Bool = true) {
      if useLoadingState {
        state = .loading
      }

      Task {
        let result = await service.getComments(postId: postId)

        switch result {
        case .success(let fetchedComments):
          state = .loaded(sortComments(fetchedComments))
          postManager.updatePost(
            id: postId,
            updates: { post in post.commentCount = fetchedComments.count }
          )
        case .failure(let error):
          state = .failed(error)
        }
      }
    }

    func toggleLike(for comment: DetailedComment) {
      guard case .loaded(var currentComments) = state else { return }

      guard
        let index = currentComments.firstIndex(where: {
          $0.commentId == comment.commentId
        })
      else { return }

      currentComments[index].isLiked.toggle()
      state = .loaded(currentComments)

      Task {
        let result = await service.toggleLike(
          postId: comment.postId,
          commentId: comment.commentId,
          isLiked: comment.isLiked
        )

        if case .failure(let error) = result {
          print("Error toggling like: \(error.localizedDescription)")
          guard case .loaded(var revertComments) = state else { return }
          if let index = revertComments.firstIndex(where: {
            $0.commentId == comment.commentId
          }) {
            revertComments[index].isLiked.toggle()
            state = .loaded(revertComments)
          }
        }
      }
    }

    private func sortComments(_ comments: [DetailedComment])
      -> [DetailedComment]
    {
      return comments.sorted { comment1, comment2 in
        let date1 = comment1.createdAt
        let date2 = comment2.createdAt

        if commentSortOrder == "Oldest First" {
          return date1 < date2
        } else {
          return date1 > date2
        }
      }
    }

    private func addCommentToList(_ comment: DetailedComment) {
      guard case .loaded(var currentComments) = state else { return }

      if let parentId = comment.parentCommentId {
        if let index = currentComments.firstIndex(where: {
          $0.commentId == parentId
        }) {
          var children = currentComments[index].children ?? []
          if commentSortOrder == "Oldest First" {
            children.append(comment)
          } else {
            children.insert(comment, at: 0)
          }
          currentComments[index].children = children
        }
      } else {
        if commentSortOrder == "Oldest First" {
          currentComments.append(comment)
        } else {
          currentComments.insert(comment, at: 0)
        }
      }

      withAnimation {
        state = .loaded(currentComments)
      }
      pendingScrollCommentId = comment.commentId
    }

    func submitComment() async -> Bool {
      let text = text.string.trimmingCharacters(
        in: .whitespacesAndNewlines
      )
      await uploadTask?.value

      let hasImage = imageState.hasPhoto
      guard !text.isEmpty || hasImage else { return false }

      let imageData: ImageData? =
        if case .uploaded(_, let data) = imageState { data } else { nil }
      guard !hasImage || imageData != nil else {
        errorMessage = "Image upload failed. Please retry or remove the image."
        showError = true
        return false
      }

      isSubmitting = true
      defer { isSubmitting = false }

      let result = await service.addComment(
        postId: postId,
        commentId: respondingToComment?.commentId,
        text: text,
        imageData: imageData
      )

      switch result {
      case .success(let newComment):
        self.respondingToComment = nil

        addCommentToList(newComment)
        resetInputState()

        if respondingToComment?.commentId != nil {
          PostHogSDK.shared.capture("comment_reply_created")
        } else {
          PostHogSDK.shared.capture("comment_created")
        }

        postManager.updatePost(id: postId) { post in
          post.commentCount += 1
        }

        return true
      case .failure(let error):
        print("Error adding comment: \(error.localizedDescription)")
        errorMessage = error.localizedDescription
        showError = true
        return false
      }
    }

    func resetInputState() {
      text = NSAttributedString(string: "")
      imageSelection = nil
      selectedRange = NSRange(location: 0, length: 0)
      withAnimation {
        respondingToComment = nil
      }
    }

    func deleteComment(_ comment: DetailedComment) async {
      guard case .loaded(let originalComments) = state else { return }

      var updatedComments = originalComments

      if let index = updatedComments.firstIndex(where: {
        $0.commentId == comment.commentId
      }) {
        updatedComments.remove(at: index)
      } else if let index = updatedComments.firstIndex(where: {
        $0.commentId == comment.parentCommentId
      }) {
        updatedComments[index].children?.removeAll(where: {
          $0.commentId == comment.commentId
        })
      } else {
        return
      }

      withAnimation {
        state = .loaded(updatedComments)
      }

      postManager.updatePost(id: postId) { post in
        post.commentCount -= 1
      }

      let result = await service.deleteComment(commentId: comment.commentId)

      if case .failure(_) = result {
        withAnimation {
          state = .loaded(originalComments)
        }

        postManager.updatePost(id: postId) { post in
          post.commentCount += 1
        }
      }
    }

    func retryImage() {
      if let imageSelection {
        cancelUpload()
        loadAndUpload(item: imageSelection)
      }
    }

    func retryUpload() {
      guard case .uploadFailed(let image) = imageState else { return }
      startUpload(image: image)
    }

    func stageCommentReply(to comment: DetailedComment) {
      respondingToComment = comment
    }

    func unstageCommentReply() {
      respondingToComment = nil
    }

    private func cancelUpload() {
      uploadTask?.cancel()
      uploadTask = nil
    }

    private func loadAndUpload(item: PhotosPickerItem) {
      imageState = .loadingPhoto

      let folder = stagingFolder
      uploadTask = Task {
        let data: Data?
        do {
          data = try await item.loadTransferable(type: Data.self)
        } catch {
          guard !Task.isCancelled else { return }
          self.imageState = .photoFailed
          self.uploadTask = nil
          return
        }
        guard !Task.isCancelled else { return }
        guard let data, let image = PlatformImage(data: data) else {
          self.imageState = data == nil ? .empty : .photoFailed
          self.uploadTask = nil
          return
        }
        self.imageState = .uploading(image)
        let imageData = await uploadImageData(image, folder: folder)
        guard !Task.isCancelled else { return }
        self.imageState =
          if let imageData { .uploaded(image, imageData) } else {
            .uploadFailed(image)
          }
        self.uploadTask = nil
      }
    }

    private func startUpload(image: PlatformImage) {
      uploadTask?.cancel()
      imageState = .uploading(image)

      let folder = stagingFolder
      uploadTask = Task {
        let imageData = await uploadImageData(image, folder: folder)
        guard !Task.isCancelled else { return }
        self.imageState =
          if let imageData { .uploaded(image, imageData) } else {
            .uploadFailed(image)
          }
        self.uploadTask = nil
      }
    }
  }
}
