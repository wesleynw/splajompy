import NukeUI
import SwiftUI

struct ImageCarousel: View {
  let images: [ImageDTO]

  @State private var selectedImage: ImageItem? = nil
  @Namespace var animation

  private let maxHeight: CGFloat = 300

  var body: some View {
    GeometryReader { geometry in
      let maxWidth = geometry.size.width - 64

      ScrollView(.horizontal) {
        ScrollViewReader { proxy in
          HStack(spacing: 12) {
            ForEach(Array(images.enumerated()), id: \.offset) {
              index,
              element in
              let aspectRatio = Double(element.width) / Double(element.height)
              let clampedAspectRatio = min(max(aspectRatio, (2 / 3)), (4 / 3))
              let width = min(maxWidth, maxHeight * clampedAspectRatio)

              CarouselImageCell(
                index: index,
                image: element,
                width: width,
                maxHeight: maxHeight,
                animation: animation,
                onSelect: {
                  guard let url = URL(string: element.imageBlobUrl) else { return }
                  selectedImage = ImageItem(id: index, url: url)
                }
              )
            }
          }
          .onReceive(
            NotificationCenter.default.publisher(for: .userDidRefreshFeed)
          ) { _ in
            withAnimation {
              proxy.scrollTo(0)
            }
          }
        }
      }
      .contentMargins(.horizontal, 16, for: .scrollContent)
      .scrollIndicators(.hidden)
      .fullScreenCover(item: $selectedImage) { imageItem in
        ImagePager(
          imageUrls: images.map { $0.imageBlobUrl },
          initialIndex: imageItem.id,
          onDismiss: { selectedImage = nil },
          namespace: animation
        )
      }
    }
    .frame(height: maxHeight)
  }
}

private struct CarouselImageCell: View {
  let index: Int
  let image: ImageDTO
  let width: CGFloat
  let maxHeight: CGFloat
  let animation: Namespace.ID
  let onSelect: () -> Void

  @State private var retryID = UUID()

  var body: some View {
    LazyImage(url: URL(string: image.imageBlobUrl)) { state in
      if let loadedImage = state.image {
        Button(action: onSelect) {
          loadedImage.resizable()
        }
        .buttonStyle(.plain)
      } else if state.error != nil {
        Button {
          retryID = UUID()
        } label: {
          Image(systemName: "arrow.clockwise")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.thinMaterial)
        }
        .buttonStyle(.plain)
      } else {
        ProgressView()
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(.thinMaterial)
      }
    }
    .processors([.resize(height: maxHeight)])
    .id(retryID)
    .aspectRatio(contentMode: .fill)
    .frame(width: width, height: maxHeight)
    .clipShape(RoundedRectangle(cornerRadius: 15))
    .contentShape(.rect)
    .modifier(
      TransitionSourceModifier(id: "image-\(index)", namespace: animation)
    )
  }
}

#Preview {
  let images = [
    ImageDTO(
      imageId: 1,
      height: 500,
      width: 200,
      imageBlobUrl:
        "https://picsum.photos/200/500",
      displayOrder: 0
    ),
    ImageDTO(
      imageId: 2,
      height: 200,
      width: 500,
      imageBlobUrl:
        "https://picsum.photos/500/200",
      displayOrder: 1
    ),
    ImageDTO(
      imageId: 3,
      height: 200,
      width: 200,
      imageBlobUrl:
        "https://picsum.photos/200/200",
      displayOrder: 2
    ),
  ]

  ImageCarousel(images: images)
}

#Preview("Error loading image") {
  let images = [
    ImageDTO(
      imageId: 1,
      height: 500,
      width: 200,
      imageBlobUrl:
        "splajompy.com",
      displayOrder: 0
    )
  ]

  ImageCarousel(images: images)
}
