import PostHog
import SwiftUI

struct ImagePager: View {
  let imageUrls: [String]
  @State private var currentIndex: Int
  @State private var isToolbarDismissed: Bool = false
  @State private var photoSaveViewModel = PhotoSaveViewModel()

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
      .tabViewStyle(.page)
      .indexViewStyle(
        .page(backgroundDisplayMode: isToolbarDismissed ? .never : .always)
      )
    }
    .statusBarHidden(isToolbarDismissed)
    .ignoresSafeArea()
    .overlay(alignment: .top) {
      ImagePagerNavigationBar(
        downloadState: $photoSaveViewModel.downloadState,
        isHidden: isToolbarDismissed,
        counter: imageUrls.count > 1
          ? "\(currentIndex + 1) of \(imageUrls.count)" : nil,
        onDismiss: onDismiss,
        onSave: {
          let urlString = imageUrls[currentIndex]
          Task {
            await photoSaveViewModel.saveImageToPhotoLibrary(
              urlString: urlString
            )
          }
        }
      )
    }
    .modifier(
      NavigationTransitionModifier(
        sourceID: "image-\(currentIndex)",
        namespace: namespace
      )
    )
    .onChange(of: currentIndex) {
      photoSaveViewModel.downloadState = .idle
    }
    .onChange(of: photoSaveViewModel.downloadState) { _, newState in
      // if successful, wait for a sec, then reset state to done
      if newState == .done {
        Task {
          try? await Task.sleep(for: .seconds(1))
          photoSaveViewModel.downloadState = .idle
        }
      } else if newState == .error {
        Task {
          try? await Task.sleep(for: .seconds(2.5))
          photoSaveViewModel.downloadState = .idle
        }
      }
    }
    .alert(
      "Photo Access Required",
      isPresented: $photoSaveViewModel.shouldShowPermissionsPrompt
    ) {
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
  }
}

private struct ImagePagerNavigationBar: View {
  @Binding var downloadState: DownloadState
  let isHidden: Bool
  let counter: String?
  let onDismiss: () -> Void
  let onSave: () -> Void

  var body: some View {
    HStack {
      if let counter {
        Text(counter)
          .padding(10)
          .font(.body.monospacedDigit())
          .foregroundStyle(.secondary)
          .modify {
            if #available(iOS 26, *) {
              $0.glassEffect(.regular.interactive(), in: .capsule)
            }
          }
      }

      Spacer()

      if PostHogSDK.shared.isFeatureEnabled("image-downloads") {
        Button(action: onSave) {
          ZStack {
            if downloadState == .downloading {
              ProgressView()
                .controlSize(.small)
            } else {
              Image(systemName: downloadState.iconName)
                .contentTransition(.symbolEffect(.replace.downUp))
                .frame(width: 20, height: 20)
            }
          }
          .frame(width: 20, height: 20)
        }
        .disabled(downloadState == .downloading)
        .buttonBorderShape(.circle)
        .controlSize(.large)
        .fontWeight(.semibold)
        .modify {
          if #available(iOS 26, *) {
            $0.buttonStyle(.glass)
          }
        }
        .sensoryFeedback(.success, trigger: downloadState) { _, newValue in
          newValue == .done
        }
        .sensoryFeedback(.error, trigger: downloadState) { _, newValue in
          newValue == .error
        }
      }
      Button(action: onDismiss) {
        Image(systemName: "xmark")
          .font(.title3)
          .frame(width: 20, height: 20)
      }
      .buttonBorderShape(.circle)
      .controlSize(.large)
      .fontWeight(.semibold)
      .modify {
        if #available(iOS 26, *) {
          $0.buttonStyle(.glass)
        }
      }
    }
    .frame(height: 40)
    .padding()
    .opacity(isHidden ? 0 : 1)
    .animation(.easeInOut(duration: 0.2), value: isHidden)
  }
}

#Preview {
  @Previewable @Namespace var previewAnimation

  let imageUrls = [
    "https://picsum.photos/2000/3000",
    "https://picsum.photos/500/500",
    "https://picsum.photos/1920/1080",
  ]

  ImagePager(
    imageUrls: imageUrls,
    initialIndex: 0,
    onDismiss: { print("dismiss") },
    namespace: previewAnimation
  )
}
