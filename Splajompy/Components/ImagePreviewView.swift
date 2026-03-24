import PhotosUI
import SwiftUI

struct ImagePreviewView: View {
  var state: PhotoState
  var onRetry: () -> Void
  var onRemove: () -> Void

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 12)
        .fill(Color.gray.opacity(0.1))
        .frame(width: 100, height: 100)

      switch state {
      case .loading:
        ProgressView()
          #if os(macOS)
            .controlSize(.small)
          #endif
      case .success(let image):
        Image(platformImage: image)
          .resizable()
          .scaledToFill()
          .frame(width: 100, height: 100)
          .clipShape(RoundedRectangle(cornerRadius: 12))
      case .failure:
        Button {
          onRetry()
        } label: {
          VStack {
            Image(systemName: "arrow.clockwise.circle.fill")
              .font(.title)
              .foregroundStyle(.blue)
            Text("Retry")
              .font(.caption2)
              .foregroundStyle(.blue)
          }
        }
        .buttonStyle(.plain)
      case .empty:
        EmptyView()
      }
    }
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
    )
    .overlay(alignment: .topTrailing) {
      Button {
        onRemove()
      } label: {
        ZStack {
          Circle()
            .fill(Color.white)
            .frame(width: 22, height: 22)
            .shadow(
              color: Color.black.opacity(0.2),
              radius: 2,
              x: 0,
              y: 1
            )

          Image(systemName: "xmark")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.gray)
        }
      }
      .offset(x: 8, y: -8)
    }
    
    .buttonStyle(.plain)
    .padding(6)
    .padding(4)
    .transition(.scale)
  }
}

#Preview("Success") {
  let image: PlatformImage = {
    #if os(iOS)
      return UIImage(systemName: "mountain.2.fill")!
    #elseif os(macOS)
      return NSImage(
        systemSymbolName: "mountain.2.fill",
        accessibilityDescription: nil
      )!
    #endif
  }()

  ImagePreviewView(
    state: .success(image),
    onRetry: {},
    onRemove: {}
  )
}
