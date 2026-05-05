import DitheringEngine
import SwiftUI

struct DitheredCard: View {
  let color: Color
  let width: CGFloat
  let height: CGFloat
  var onLoaded: (() -> Void)? = nil

  @State private var image: UIImage?

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 12)
        .fill(color.gradient)
        .frame(width: width, height: height)
      if let image {
        Image(uiImage: image)
          .resizable()
          .interpolation(.none)
          .frame(width: width, height: height)
          .clipShape(RoundedRectangle(cornerRadius: 12))
          .transition(.opacity)
      }
    }
    .animation(.easeInOut(duration: 0.4), value: image != nil)
    .task(id: width) {
      guard image == nil, width > 0 else { return }
      image = await render()
      if image != nil { onLoaded?() }
    }
  }

  @MainActor
  private func render() async -> UIImage? {
    let pixelSize: CGFloat = 2
    let renderScale = 1 / pixelSize

    let gradientView = LinearGradient(
      colors: [color, color.opacity(0.3)],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
    .frame(width: width, height: height)

    let renderer = ImageRenderer(content: gradientView)
    renderer.scale = renderScale
    guard let src = renderer.uiImage, let cgImage = src.cgImage else {
      return nil
    }

    return await Task.detached(priority: .userInitiated) {
      let engine = DitheringEngine()
      try? engine.set(image: cgImage)
      guard
        let result = try? engine.dither(
          usingMethod: .atkinson,
          andPalette: .cga,
          withDitherMethodSettings: FloydSteinbergSettingsConfiguration(),
          withPaletteSettings: QuantizedColorSettingsConfiguration(bits: 1)
        )
      else { return nil }
      return UIImage(cgImage: result, scale: 1, orientation: .up)
    }.value
  }
}
