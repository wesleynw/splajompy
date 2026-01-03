import NukeUI
import SwiftUI

#if os(iOS)

  /// A zoomable, pannable async image display. Wraps UIScrollView and LazyImageView.
  struct ZoomableAsyncImage: UIViewRepresentable {
    let imageUrl: String

    func makeUIView(context: Context) -> some UIView {
      let scrollView = UIScrollView()
      let imageLoaderView = LazyImageView()

      scrollView.delegate = context.coordinator
      context.coordinator.imageLoaderView = imageLoaderView

      scrollView.minimumZoomScale = 1
      scrollView.maximumZoomScale = 4

      let doubleTapRecognizer = UITapGestureRecognizer(
        target: context.coordinator,
        action: #selector(Coordinator.handleDoubleTap(_:))
      )
      doubleTapRecognizer.numberOfTapsRequired = 2
      scrollView.addGestureRecognizer(doubleTapRecognizer)

      imageLoaderView.placeholderView = UIActivityIndicatorView()
      imageLoaderView.url = URL(string: imageUrl)
      imageLoaderView.imageView.contentMode = .scaleAspectFit
      imageLoaderView.imageView.backgroundColor = .clear

      imageLoaderView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
      scrollView.addSubview(imageLoaderView)

      return scrollView
    }

    func updateUIView(_ uiView: UIViewType, context: Context) {
      context.coordinator.imageLoaderView?.url = URL(string: imageUrl)
    }

    func makeCoordinator() -> Coordinator {
      Coordinator()
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
      weak var imageLoaderView: LazyImageView?

      func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageLoaderView
      }

      @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        guard let scrollView = gesture.view as? UIScrollView else { return }
        if scrollView.zoomScale == 1 {
          let point = gesture.location(in: imageLoaderView)
          let zoomRect = zoomRectForScale(
            scale: scrollView.maximumZoomScale,
            center: point,
            scrollView: scrollView
          )
          scrollView.zoom(to: zoomRect, animated: true)
        } else {
          scrollView.setZoomScale(1, animated: true)
        }
      }

      private func zoomRectForScale(
        scale: CGFloat,
        center: CGPoint,
        scrollView: UIScrollView
      ) -> CGRect {
        var zoomRect = CGRect.zero
        zoomRect.size.height = scrollView.frame.size.height / scale
        zoomRect.size.width = scrollView.frame.size.width / scale
        zoomRect.origin.x = center.x - (zoomRect.size.width / 2.0)
        zoomRect.origin.y = center.y - (zoomRect.size.height / 2.0)
        return zoomRect
      }
    }
  }

  #Preview {
    let url: String =
      "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg"

    ZoomableAsyncImage(imageUrl: url)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

#endif
