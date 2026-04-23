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
  @State private var isToolbarDismissed: Bool = false

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
    Group {
      #if os(iOS)
        TabView(selection: $currentIndex) {
          ForEach(Array(imageUrls.enumerated()), id: \.offset) { index, url in
            ZoomableAsyncImage(
              imageUrl: url,
              cornerRadius: 0,
              isShowingAccessories: !isToolbarDismissed,
              onTap: { withAnimation { isToolbarDismissed.toggle() } }
            )
            .ignoresSafeArea()
            .tag(index)
          }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .ignoresSafeArea()
        .overlay(alignment: .top) {
          ImagePagerNavigationBar(
            isHidden: isToolbarDismissed,
            counter: imageUrls.count > 1 ? "\(currentIndex + 1) of \(imageUrls.count)" : nil,
            showDownload: PostHogSDK.shared.isFeatureEnabled("image-downloads"),
            onDismiss: onDismiss,
            onSave: {
              let urlString = imageUrls[currentIndex]
              Task { await saveImageToPhotoLibrary(urlString: urlString) }
            }
          )
          .allowsHitTesting(false)
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
    #if os(iOS)
      .statusBarHidden(isToolbarDismissed)
    #endif
    .ignoresSafeArea()
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

    @ViewBuilder
    private var saveButton: some View {
      Button(action: {
        let urlString = imageUrls[currentIndex]
        Task {
          await saveImageToPhotoLibrary(urlString: urlString)
        }
      }) {
        switch downloadState {
        case .downloading:
          ProgressView()
            .controlSize(.small)
        case .done:
          Label("Saved", systemImage: "checkmark").labelStyle(.iconOnly)
        case .error:
          Label("Error", systemImage: "exclamationmark.triangle").labelStyle(.iconOnly)
        case .idle:
          Label("Save", systemImage: "arrow.down.to.line").labelStyle(.iconOnly)
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
  #endif
}

#if os(iOS)
  private struct ImagePagerNavigationBar: UIViewRepresentable {
    let isHidden: Bool
    let counter: String?
    let showDownload: Bool
    let onDismiss: () -> Void
    let onSave: () -> Void

    func makeUIView(context: Context) -> UIView {
      let container = UIView()
      container.backgroundColor = .clear

      let bar = UINavigationBar()
      let appearance = UINavigationBarAppearance()
      appearance.configureWithDefaultBackground()
      bar.standardAppearance = appearance
      bar.scrollEdgeAppearance = appearance

      let item = UINavigationItem()
      item.rightBarButtonItems = context.coordinator.makeTrailingItems()
      if let counter = counter {
        item.leftBarButtonItem = context.coordinator.makeCounterItem(counter)
      }
      bar.setItems([item], animated: false)

      bar.translatesAutoresizingMaskIntoConstraints = false
      container.addSubview(bar)
      NSLayoutConstraint.activate([
        bar.topAnchor.constraint(equalTo: container.safeAreaLayoutGuide.topAnchor),
        bar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
        bar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      ])

      context.coordinator.bar = bar
      return container
    }

    func updateUIView(_ container: UIView, context: Context) {
      context.coordinator.onDismiss = onDismiss
      context.coordinator.onSave = onSave

      if let item = context.coordinator.bar?.topItem {
        item.rightBarButtonItems = context.coordinator.makeTrailingItems()
        item.leftBarButtonItem = counter.map { context.coordinator.makeCounterItem($0) }
      }

      UIView.animate(withDuration: 0.2) {
        container.alpha = self.isHidden ? 0 : 1
      }
    }

    func makeCoordinator() -> Coordinator {
      Coordinator(onDismiss: onDismiss, onSave: onSave, showDownload: showDownload)
    }

    @MainActor
    class Coordinator: NSObject {
      var onDismiss: () -> Void
      var onSave: () -> Void
      let showDownload: Bool
      weak var bar: UINavigationBar?

      init(onDismiss: @escaping () -> Void, onSave: @escaping () -> Void, showDownload: Bool) {
        self.onDismiss = onDismiss
        self.onSave = onSave
        self.showDownload = showDownload
      }

      func makeTrailingItems() -> [UIBarButtonItem] {
        let closeItem = UIBarButtonItem(
          image: UIImage(systemName: "xmark"),
          style: .plain,
          target: self,
          action: #selector(handleDismiss)
        )
        guard showDownload else { return [closeItem] }
        let saveItem = UIBarButtonItem(
          image: UIImage(systemName: "arrow.down.to.line"),
          style: .plain,
          target: self,
          action: #selector(handleSave)
        )
        return [closeItem, saveItem]
      }

      func makeCounterItem(_ text: String) -> UIBarButtonItem {
        let label = UILabel()
        label.text = text
        label.font = .monospacedDigitSystemFont(ofSize: 17, weight: .regular)
        label.textColor = .secondaryLabel
        return UIBarButtonItem(customView: label)
      }

      @objc func handleDismiss() { onDismiss() }
      @objc func handleSave() { onSave() }
    }
  }
#endif

#Preview("Fullscreen Images") {
  @Previewable @Namespace var previewAnimation

  let imageUrls = [
    "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/production/6/comment/11713/4b5d1415-3a84-4acd-884f-3b4233993880.jpg?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Checksum-Mode=ENABLED&X-Amz-Credential=DO00R7A3VXT8XKRVG3JT%2F20260422%2Fnyc3%2Fs3%2Faws4_request&X-Amz-Date=20260422T193143Z&X-Amz-Expires=86400&X-Amz-SignedHeaders=host&x-id=GetObject&X-Amz-Signature=b71155b0076b65aae03ca224798d02cccb764bcf7681d3d92b67e82a9600f68f",
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
