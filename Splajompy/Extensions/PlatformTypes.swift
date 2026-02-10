import SwiftUI

#if os(iOS)
  import UIKit
  typealias PlatformImage = UIImage
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
