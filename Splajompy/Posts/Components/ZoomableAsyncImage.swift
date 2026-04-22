import NukeUI
import SwiftUI

/// A zoomable, pannable async image display. Wraps UIScrollView and LazyImageView.
struct ZoomableAsyncImage: UIViewRepresentable {
  let imageUrl: String
  var cornerRadius: CGFloat = 0
  var isShowingAccessories: Bool

  func makeUIView(context: Context) -> some UIView {
    let scrollView = UIScrollView()
    let imageLoaderView = LazyImageView()

    scrollView.delegate = context.coordinator
    context.coordinator.imageLoaderView = imageLoaderView

    scrollView.minimumZoomScale = 0.8
    scrollView.maximumZoomScale = 4

    let doubleTapRecognizer = UITapGestureRecognizer(
      target: context.coordinator,
      action: #selector(Coordinator.handleDoubleTap(_:))
    )
    doubleTapRecognizer.numberOfTapsRequired = 2
    scrollView.addGestureRecognizer(doubleTapRecognizer)

    scrollView.showsHorizontalScrollIndicator = false
    scrollView.showsVerticalScrollIndicator = false
    scrollView.contentInsetAdjustmentBehavior = .never

    imageLoaderView.placeholderView = UIActivityIndicatorView()
    imageLoaderView.processors = [
      .resize(size: UIScreen.main.bounds.size, contentMode: .aspectFit),
      .roundedCorners(radius: cornerRadius, unit: .points),
    ]
    imageLoaderView.url = URL(string: imageUrl)
    imageLoaderView.imageView.contentMode = .scaleAspectFit
    imageLoaderView.imageView.backgroundColor = .clear

    imageLoaderView.translatesAutoresizingMaskIntoConstraints = false
    scrollView.addSubview(imageLoaderView)

    NSLayoutConstraint.activate([
      imageLoaderView.leadingAnchor.constraint(
        equalTo: scrollView.leadingAnchor
      ),
      imageLoaderView.trailingAnchor.constraint(
        equalTo: scrollView.trailingAnchor
      ),
      imageLoaderView.topAnchor.constraint(equalTo: scrollView.topAnchor),
      imageLoaderView.bottomAnchor.constraint(
        equalTo: scrollView.bottomAnchor
      ),
      imageLoaderView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
      imageLoaderView.heightAnchor.constraint(
        equalTo: scrollView.heightAnchor
      ),
    ])

    scrollView.addSubview(imageLoaderView)

    return scrollView
  }

  func updateUIView(_ uiView: UIViewType, context: Context) {
    let newURL = URL(string: imageUrl)
    if context.coordinator.imageLoaderView?.url != newURL {
      context.coordinator.imageLoaderView?.url = newURL
    }
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

  ZoomableAsyncImage(imageUrl: url, isShowingAccessories: true)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}
