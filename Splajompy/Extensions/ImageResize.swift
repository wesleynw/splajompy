import UIKit

extension UIImage {
  func resize(newWidth: CGFloat) -> UIImage? {
    let scaleFactor = newWidth / self.size.width
    let newHeight = self.size.height * scaleFactor
    let newSize = CGSize(width: floor(newWidth), height: floor(newHeight))

    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 1.0
    let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
    return renderer.image { _ in
      draw(in: CGRect(origin: .zero, size: newSize))
    }
  }
}
