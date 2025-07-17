#if os(iOS)

  import SwiftUI

  struct ZoomableModifier: ViewModifier {
    let minZoomScale: CGFloat
    let doubleTapZoomScale: CGFloat

    @State private var lastTransform: CGAffineTransform = .identity
    @State private var transform: CGAffineTransform = .identity
    @State private var contentSize: CGSize = .zero

    func body(content: Content) -> some View {
      content
        .background(alignment: .topLeading) {
          GeometryReader { proxy in
            Color.clear
              .onAppear {
                contentSize = proxy.size
              }
          }
        }
        .animatableTransformEffect(transform)
        .highPriorityGesture(
          dragGesture,
          including: transform == .identity ? .none : .all
        )
        .modify { view in
          if #available(iOS 17.0, *) {
            view.simultaneousGesture(magnificationGesture)
          } else {
            view.simultaneousGesture(oldMagnificationGesture)
          }
        }
        .gesture(doubleTapGesture)
    }

    @available(iOS, introduced: 16.0, deprecated: 17.0)
    private var oldMagnificationGesture: some Gesture {
      MagnificationGesture()
        .onChanged { value in
          let zoomFactor = 0.5
          let scale = value * zoomFactor
          let newTransform = lastTransform.scaledBy(x: scale, y: scale)
          transform = limitTransformForGesture(newTransform)
        }
        .onEnded { _ in
          onEndGesture()
        }
    }

    @available(iOS 17.0, *)
    private var magnificationGesture: some Gesture {
      MagnifyGesture(minimumScaleDelta: 0)
        .onChanged { value in
          let newTransform = CGAffineTransform.anchoredScale(
            scale: value.magnification,
            anchor: value.startAnchor.scaledBy(contentSize)
          )

          withAnimation(.interactiveSpring) {
            transform = limitTransformForGesture(lastTransform.concatenating(newTransform))
          }
        }
        .onEnded { _ in
          onEndGesture()
        }
    }

    private var doubleTapGesture: some Gesture {
      SpatialTapGesture(count: 2)
        .onEnded { value in
          let newTransform: CGAffineTransform =
            if transform.isIdentity {
              .anchoredScale(scale: doubleTapZoomScale, anchor: value.location)
            } else {
              .identity
            }

          withAnimation(.linear(duration: 0.15)) {
            transform = newTransform
            lastTransform = newTransform
          }
        }
    }

    private var dragGesture: some Gesture {
      DragGesture()
        .onChanged { value in
          withAnimation(.interactiveSpring) {
            let newTransform = lastTransform.translatedBy(
              x: value.translation.width / transform.scaleX,
              y: value.translation.height / transform.scaleY
            )
            transform = limitTransform(newTransform)
          }
        }
        .onEnded { _ in
          onEndGesture()
        }
    }

    private func onEndGesture() {
      let newTransform = limitTransform(transform)

      withAnimation(.snappy(duration: 0.1)) {
        transform = newTransform
        lastTransform = newTransform
      }
    }

    private func limitTransformForGesture(_ transform: CGAffineTransform)
      -> CGAffineTransform
    {
      let scaleX = transform.scaleX
      let scaleY = transform.scaleY

      // Limit minimum zoom
      if scaleX < minZoomScale || scaleY < minZoomScale {
        return .identity
      }

      // Allow over-zooming during gestures (no max limit for pinch)
      // Just limit pan boundaries
      let maxX = contentSize.width * (scaleX - 1)
      let maxY = contentSize.height * (scaleY - 1)

      // Allow some over-scroll for pan
      let bufferX = contentSize.width * 0.2
      let bufferY = contentSize.height * 0.2

      let minTx = -maxX - bufferX
      let maxTx = bufferX
      let minTy = -maxY - bufferY
      let maxTy = bufferY

      if transform.tx > maxTx
        || transform.tx < minTx
        || transform.ty > maxTy
        || transform.ty < minTy
      {
        let tx = min(max(transform.tx, minTx), maxTx)
        let ty = min(max(transform.ty, minTy), maxTy)
        var limitedTransform = transform
        limitedTransform.tx = tx
        limitedTransform.ty = ty
        return limitedTransform
      }

      return transform
    }

    private func limitTransform(_ transform: CGAffineTransform)
      -> CGAffineTransform
    {
      let scaleX = transform.scaleX
      let scaleY = transform.scaleY

      // Limit minimum zoom
      if scaleX < minZoomScale || scaleY < minZoomScale {
        return .identity
      }

      // Reset to max zoom if over-zoomed
      let maxZoomScale: CGFloat = 3.0
      let finalScale = min(max(scaleX, minZoomScale), maxZoomScale)

      // Calculate pan boundaries for final scale
      let maxX = contentSize.width * (finalScale - 1)
      let maxY = contentSize.height * (finalScale - 1)

      let minTx = -maxX
      let maxTx: CGFloat = 0
      let minTy = -maxY
      let maxTy: CGFloat = 0

      let tx = min(max(transform.tx, minTx), maxTx)
      let ty = min(max(transform.ty, minTy), maxTy)

      return CGAffineTransform(a: finalScale, b: 0, c: 0, d: finalScale, tx: tx, ty: ty)
    }
  }

  extension View {
    @ViewBuilder
    public func zoomable(
      minZoomScale: CGFloat = 1,
      doubleTapZoomScale: CGFloat = 3
    ) -> some View {
      modifier(
        ZoomableModifier(
          minZoomScale: minZoomScale,
          doubleTapZoomScale: doubleTapZoomScale
        )
      )
    }

    @ViewBuilder
    public func zoomable(
      minZoomScale: CGFloat = 1,
      doubleTapZoomScale: CGFloat = 3,
      outOfBoundsColor: Color = .clear
    ) -> some View {
      GeometryReader { proxy in
        ZStack {
          outOfBoundsColor
          self.zoomable(
            minZoomScale: minZoomScale,
            doubleTapZoomScale: doubleTapZoomScale
          )
        }
      }
    }
  }

  extension View {
    @ViewBuilder
    fileprivate func modify(@ViewBuilder _ fn: (Self) -> some View) -> some View {
      fn(self)
    }

    @ViewBuilder
    fileprivate func animatableTransformEffect(_ transform: CGAffineTransform)
      -> some View
    {
      scaleEffect(
        x: transform.scaleX,
        y: transform.scaleY,
        anchor: .zero
      )
      .offset(x: transform.tx, y: transform.ty)
    }
  }

  extension UnitPoint {
    fileprivate func scaledBy(_ size: CGSize) -> CGPoint {
      .init(
        x: x * size.width,
        y: y * size.height
      )
    }
  }

  extension CGAffineTransform {
    fileprivate static func anchoredScale(scale: CGFloat, anchor: CGPoint)
      -> CGAffineTransform
    {
      CGAffineTransform(translationX: anchor.x, y: anchor.y)
        .scaledBy(x: scale, y: scale)
        .translatedBy(x: -anchor.x, y: -anchor.y)
    }

    fileprivate var scaleX: CGFloat {
      sqrt(a * a + c * c)
    }

    fileprivate var scaleY: CGFloat {
      sqrt(b * b + d * d)
    }
  }

#endif
