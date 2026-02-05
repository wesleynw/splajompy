import Nuke
import SwiftUI

#if os(iOS)
  import Photos
  import PostHog
#endif

/// Full-screen pager for async images.
struct ImagePager: View {
  let imageUrls: [String]
  @State private var currentIndex: Int
  @State private var downloadState: DownloadState = .idle
  @State private var showPermissionAlert = false

  enum DownloadState {
    case idle, downloading, done, error
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
        ForEach(Array(imageUrls.enumerated()), id: \.offset) { index, url in
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
          if PostHogSDK.shared.isFeatureEnabled("image-downloads") {
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
                case .error:
                  Image(systemName: "exclamationmark.triangle")
                case .idle:
                  Image(systemName: "arrow.down.to.line")
                }
              }
              .contentTransition(.symbolEffect(.replace))
              .disabled(downloadState == .downloading)
              .sensoryFeedback(.success, trigger: downloadState) { _, newValue in
                newValue == .done
              }
              .sensoryFeedback(.error, trigger: downloadState) { _, newValue in
                newValue == .error
              }
            }

            if #available(iOS 26, *) {
              ToolbarSpacer(.fixed, placement: .topBarTrailing)
            }
          }

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
    .onChange(of: currentIndex) {
      downloadState = .idle
    }
    .onChange(of: downloadState) {
      if downloadState == .error {
        Task {
          try? await Task.sleep(for: .seconds(2.5))
          await MainActor.run { downloadState = .idle }
        }
      }
    }
    #if os(iOS)
      .alert("Photo Access Required", isPresented: $showPermissionAlert) {
        Button("Open Settings") {
          if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
          } else {
            print("issue constructing app settings link")
          }
        }
        Button("Cancel", role: .cancel) {}
      } message: {
        Text("Please allow photo library access in Settings to save images.")
      }
    #endif
  }

  #if os(iOS)
    nonisolated
      private func saveImageToPhotoLibrary(urlString: String) async
    {
      let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
      guard status == .authorized || status == .limited else {
        await MainActor.run { showPermissionAlert = true }
        return
      }

      guard let url = URL(string: urlString) else {
        await MainActor.run { downloadState = .error }
        return
      }

      let startTime = ContinuousClock.now
      await MainActor.run { downloadState = .downloading }

      guard let image = try? await ImagePipeline.shared.image(for: url) else {
        await MainActor.run { downloadState = .error }
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
        await MainActor.run { downloadState = .error }
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
