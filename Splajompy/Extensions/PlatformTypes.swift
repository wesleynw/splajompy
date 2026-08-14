import SwiftUI

#if os(iOS)
  import UIKit
  typealias PlatformImage = UIImage

  extension UIImage {
    func resized(longEdge maxLength: CGFloat) -> UIImage {
      let longestEdge = max(size.width, size.height)
      guard longestEdge > maxLength else { return self }
      let scale = maxLength / longestEdge
      let newSize = CGSize(width: size.width * scale, height: size.height * scale)

      let format = UIGraphicsImageRendererFormat.default()
      format.scale = 1.0
      return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
        self.draw(in: CGRect(origin: .zero, size: newSize))
      }
    }
  }
#elseif os(macOS)
  import AppKit
  typealias PlatformImage = NSImage

  extension NSImage {
    func jpegData(compressionQuality: CGFloat) -> Data? {
      guard let tiff = tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff)
      else { return nil }
      return bitmap.representation(
        using: .jpeg,
        properties: [.compressionFactor: compressionQuality]
      )
    }

    var pixelSize: CGSize {
      guard let rep = representations.first else { return size }
      return CGSize(width: rep.pixelsWide, height: rep.pixelsHigh)
    }

    func resized(longEdge maxLength: CGFloat) -> NSImage {
      let longestEdge = max(pixelSize.width, pixelSize.height)
      guard longestEdge > maxLength else { return self }
      let scale = maxLength / longestEdge
      let newSize = CGSize(width: pixelSize.width * scale, height: pixelSize.height * scale)

      let newImage = NSImage(size: newSize)
      newImage.lockFocus()
      draw(in: NSRect(origin: .zero, size: newSize), from: .zero, operation: .copy, fraction: 1.0)
      newImage.unlockFocus()
      return newImage
    }
  }
#endif

extension PlatformImage {
  var uploadSize: CGSize {
    #if os(iOS)
      return size
    #else
      return pixelSize
    #endif
  }
}

extension Image {
  init(platformImage: PlatformImage) {
    #if os(iOS)
      self.init(uiImage: platformImage)
    #else
      self.init(nsImage: platformImage)
    #endif
  }
}
