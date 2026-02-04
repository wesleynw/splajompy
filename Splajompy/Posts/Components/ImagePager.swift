import SwiftUI

#if os(iOS)
  import Photos
#endif

/// Full-screen pager for async images.
struct ImagePager: View {
  let imageUrls: [String]
  @State private var currentIndex: Int
  @State private var downloadState: DownloadState = .idle

  enum DownloadState {
    case idle, downloading, done
  }
  let onDismiss: () -> Void
  let namespace: Namespace.ID

  init(
    imageUrls: [String],
    initialIndex: Int,
    onDismiss: @escaping () -> Void,
    namespace: Namespace.ID
  ) {
    self.imageUrls = imageUrls
    self._currentIndex = State(initialValue: initialIndex)
    self.onDismiss = onDismiss
    self.namespace = namespace
  }

  var body: some View {
    NavigationStack {
      TabView(selection: $currentIndex) {
        ForEach(Array(imageUrls.enumerated()), id: \.1) { index, url in
          #if os(iOS)
            ZoomableAsyncImage(imageUrl: url)
              .edgesIgnoringSafeArea(.all)
              .tag(index)
          #else
            ZoomableAsyncImageMac(imageUrl: url)
              .edgesIgnoringSafeArea(.all)
              .tag(index)
          #endif
        }
      }
      #if os(iOS)
        .tabViewStyle(PageTabViewStyle())
        .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
      #endif
      .toolbar {
        #if os(iOS)
          ToolbarItemGroup(placement: .topBarTrailing) {
            Button(action: {
              let urlString = imageUrls[currentIndex]
              Task {
                await saveImageToPhotoLibrary(urlString: urlString)
              }
            }) {
              switch downloadState {
              case .downloading:
                ProgressView()
              case .done:
                Image(systemName: "checkmark")
              case .idle:
                Image(systemName: "arrow.down.to.line")
              }
            }
            .disabled(downloadState == .downloading)
          }

          if #available(iOS 26, *) {
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
          }
        #endif
        #if os(iOS)
          ToolbarItemGroup(placement: .topBarTrailing) {
            Button(action: onDismiss) {
              Image(systemName: "xmark")
            }
          }
        #else
          ToolbarItemGroup(placement: .automatic) {
            Button(action: onDismiss) {
              Image(systemName: "xmark")
            }
          }
        #endif
      }
    }
    .modifier(
      NavigationTransitionModifier(
        sourceID: "image-\(currentIndex)",
        namespace: namespace
      )
    )
  }

  #if os(iOS)
    nonisolated
      private func saveImageToPhotoLibrary(urlString: String) async
    {
      let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
      guard status == .authorized else { return }

      guard let url = URL(string: urlString) else { return }

      let startTime = ContinuousClock.now
      await MainActor.run { downloadState = .downloading }

      guard let (data, _) = try? await URLSession.shared.data(from: url),
        let image = UIImage(data: data)
      else {
        await MainActor.run { downloadState = .idle }
        return
      }

      do {
        try await PHPhotoLibrary.shared().performChanges {
          PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
        let elapsed = ContinuousClock.now - startTime
        if elapsed < .seconds(1) {
          try? await Task.sleep(for: .seconds(1) - elapsed)
        }
        await MainActor.run { downloadState = .done }
      } catch {
        print("Error saving to photo library: \(error)")
        await MainActor.run { downloadState = .idle }
      }
    }
  #endif
}

#Preview("Fullscreen Images") {
  @Previewable @Namespace var previewAnimation

  let imageUrls = [
    "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
    "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
    "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
  ]

  ImagePager(
    imageUrls: imageUrls,
    initialIndex: 0,
    onDismiss: { print("dismiss") },
    namespace: previewAnimation
  )
}
