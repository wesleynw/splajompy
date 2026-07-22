import NukeUI
import SwiftUI

struct ImageCarousel: View {
  let images: [ImageDTO]

  @State private var selectedImage: ImageItem? = nil
  @Namespace var animation

  private let maxHeight: CGFloat = 300

  var body: some View {
    GeometryReader { geometry in
      let maxWidth = geometry.size.width - 32

      ScrollView(.horizontal) {
        ScrollViewReader { proxy in
          HStack {
            ForEach(Array(images.enumerated()), id: \.offset) {
              index,
              element in
              carouselCell(index: index, image: element, maxWidth: maxWidth)
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

  private func carouselCell(index: Int, image: ImageDTO, maxWidth: CGFloat)
    -> some View
  {
    let aspectRatio = Double(image.width) / Double(image.height)
    let clampedAspectRatio = min(max(aspectRatio, (2 / 3)), (4 / 3))
    let width = min(maxWidth, maxHeight * clampedAspectRatio)

    return Button {
      selectedImage = ImageItem(
        id: index,
        url: URL(string: image.imageBlobUrl)!
      )
    } label: {
      LazyImage(url: URL(string: image.imageBlobUrl)) { state in
        if let image = state.image {
          image.resizable()
        } else if state.error != nil {
          Image(systemName: "arrow.clockwise")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.thinMaterial)
        } else {
          ProgressView()
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.thinMaterial)
        }
      }
      .processors([.resize(height: maxHeight)])
      .aspectRatio(contentMode: .fill)
      .frame(width: width, height: maxHeight)
      .clipShape(RoundedRectangle(cornerRadius: 15))
      .contentShape(.rect)
      .modifier(
        TransitionSourceModifier(id: "image-\(index)", namespace: animation)
      )
    }
    .buttonStyle(.plain)
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
