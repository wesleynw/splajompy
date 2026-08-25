import NukeUI
import SwiftUI

struct SingleImageCellView: View {
  var animation: Namespace.ID
  let image: ImageDTO
  let onSelect: (URL) -> Void

  var body: some View {
    if let url = URL(string: image.imageBlobUrl) {
      let rawAspectRatio = CGFloat(image.width) / CGFloat(image.height)
      let clampedAspectRatio = min(max(rawAspectRatio, 0.4), 2.5)

      Button {
        onSelect(url)
      } label: {
        LazyImage(url: url) { state in
          if let img = state.image {
            img.resizable()
              .aspectRatio(contentMode: .fill)
          } else if state.error != nil {
            Color.clear
              .background(.thinMaterial)
              .overlay {
                Image(systemName: "photo.badge.exclamationmark")
                  .foregroundStyle(.secondary)
              }
          } else {
            Color.clear
              .background(.thinMaterial)
              .overlay {
                ProgressView()
                  #if os(macOS)
                    .controlSize(.small)
                  #endif
              }
          }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 100, maxHeight: 500)
        .aspectRatio(clampedAspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .contentShape(.rect)
        .modifier(TransitionSourceModifier(id: "image-0", namespace: animation))
      }
      .buttonStyle(.plain)
    }
  }
}

#Preview {
  let image = ImageDTO(
    imageId: 0,
    height: 100,
    width: 500,
    imageBlobUrl: "https://picsum.photos/500/100",
    displayOrder: 0
  )

  SingleImageCellView(
    animation: Namespace().wrappedValue,
    image: image,
    onSelect: { _ in }
  )
  .padding()
}
