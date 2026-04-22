import Nuke
import PostHog
import SwiftUI

#if os(iOS)
  import Photos
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
      Group {
        #if os(iOS)
          VStack(spacing: 0) {
            TabView(selection: $currentIndex) {
              ForEach(Array(imageUrls.enumerated()), id: \.offset) { index, url in
                ZoomableAsyncImage(imageUrl: url, cornerRadius: 20)
                  .tag(index)
              }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))

            if imageUrls.count > 1 {
              HStack(spacing: 8) {
                ForEach(0..<imageUrls.count, id: \.self) { index in
                  Circle()
                    .fill(index == currentIndex ? Color.primary : Color.secondary.opacity(0.4))
                    .frame(width: 7, height: 7)
                }
              }
              .padding(.horizontal, 12)
              .padding(.vertical, 8)
              .background(.ultraThinMaterial, in: .capsule)
              .padding(.top, 8)
            }
          }
        #else
          ZStack {
            ZoomableAsyncImageMac(imageUrl: imageUrls[currentIndex])
              .id(currentIndex)
              .edgesIgnoringSafeArea(.all)

            if imageUrls.count > 1 {
              HStack {
                Button {
                  withAnimation { currentIndex -= 1 }
                } label: {
                  Image(systemName: "chevron.left")
                    .font(.title)
                    .padding()
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.leftArrow, modifiers: [])
                .disabled(currentIndex == 0)

                Spacer()

                Button {
                  withAnimation { currentIndex += 1 }
                } label: {
                  Image(systemName: "chevron.right")
                    .font(.title)
                    .padding()
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.rightArrow, modifiers: [])
                .disabled(currentIndex == imageUrls.count - 1)
              }
              .padding(.horizontal)
            }
          }
        #endif
      }
      .toolbar {
        #if os(iOS)
          if PostHogSDK.shared.isFeatureEnabled("image-downloads") {
            saveImageToolbarItem
          }
        #else
          ToolbarItem(placement: .principal) {
            if imageUrls.count > 1 {
              Text("\(currentIndex + 1) of \(imageUrls.count)")
                .monospacedDigit()
                .foregroundStyle(.secondary)
            }
          }
        #endif

        ToolbarItemGroup(
          placement: {
            #if os(iOS)
              .topBarTrailing
            #else
              .cancellationAction
            #endif
          }()
        ) {
          if #available(iOS 26, macOS 26, *) {
            Button(role: .close) {
              onDismiss()
            }
          } else {
            Button("Close", systemImage: "xmark") {
              onDismiss()
            }
          }
        }
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
          downloadState = .idle
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

    @ToolbarContentBuilder
    private var saveImageToolbarItem: some ToolbarContent {
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
        .sensoryFeedback(.success, trigger: downloadState) {
          _,
          newValue in
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
  #endif
}

#Preview("Fullscreen Images") {
  @Previewable @Namespace var previewAnimation

  let imageUrls = [
    "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/production/6/comment/11713/4b5d1415-3a84-4acd-884f-3b4233993880.jpg?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Checksum-Mode=ENABLED&X-Amz-Credential=DO00R7A3VXT8XKRVG3JT%2F20260421%2Fnyc3%2Fs3%2Faws4_request&X-Amz-Date=20260421T232747Z&X-Amz-Expires=86400&X-Amz-SignedHeaders=host&x-id=GetObject&X-Amz-Signature=6f872c7b4a9fd64ee28986be21e610b4a1bc637c9a724744b41c62fe52a4854b",
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
