import NukeUI
import SwiftUI

struct ImageGallery: View {
  let images: [ImageDTO]

  @State private var selectedImageIndex: Int? = nil
  @Environment(\.colorScheme) var colorScheme
  @Namespace var animation

  var body: some View {
    Group {
      if images.isEmpty {
        EmptyView()
      } else if images.count == 1 {
        singleImageCell()
      } else {
        multipleImagesLayout()
      }
    }
    #if os(iOS)
      .fullScreenCover(
        item: Binding<ImageItem?>(
          get: {
            guard let index = selectedImageIndex, index < images.count else {
              return nil
            }
            return ImageItem(
              id: index,
              url: URL(string: images[index].imageBlobUrl)!
            )
          },
          set: { selectedImageIndex = $0?.id }
        )
      ) { imageItem in
        ImagePager(
          imageUrls: images.map { $0.imageBlobUrl },
          initialIndex: imageItem.id,
          onDismiss: { selectedImageIndex = nil },
          namespace: animation
        )
      }
    #else
      .sheet(
        item: Binding<ImageItem?>(
          get: {
            guard let index = selectedImageIndex, index < images.count else {
              return nil
            }
            return ImageItem(
              id: index,
              url: URL(string: images[index].imageBlobUrl)!
            )
          },
          set: { selectedImageIndex = $0?.id }
        )
      ) { imageItem in
        ImagePager(
          imageUrls: images.map { $0.imageBlobUrl },
          initialIndex: imageItem.id,
          onDismiss: { selectedImageIndex = nil },
          namespace: animation
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .presentationSizing(.page)
      }
    #endif
  }

  private func multipleImagesLayout() -> some View {
    GeometryReader { geometry in
      if images.count == 2 {
        HStack(spacing: 4) {
          imageCell(
            index: 0,
            width: (geometry.size.width - 4) / 2,
            height: geometry.size.height,
            bottomTrailing: 0,
            topTrailing: 0
          )

          imageCell(
            index: 1,
            width: (geometry.size.width - 4) / 2,
            height: geometry.size.height,
            topLeading: 0,
            bottomLeading: 0
          )
        }
      } else if images.count == 3 {
        HStack(spacing: 4) {
          imageCell(
            index: 0,
            width: (geometry.size.width - 4) / 2,
            height: geometry.size.height,
            bottomTrailing: 0,
            topTrailing: 0
          )

          VStack(spacing: 4) {
            imageCell(
              index: 1,
              width: (geometry.size.width - 4) / 2,
              height: (geometry.size.height - 4) / 2,
              topLeading: 0,
              bottomLeading: 0,
              bottomTrailing: 0
            )

            imageCell(
              index: 2,
              width: (geometry.size.width - 4) / 2,
              height: (geometry.size.height - 4) / 2,
              topLeading: 0,
              bottomLeading: 0,
              topTrailing: 0
            )
          }
        }
      } else {
        VStack(spacing: 4) {
          HStack(spacing: 4) {
            imageCell(
              index: 0,
              width: (geometry.size.width - 4) / 2,
              height: (geometry.size.height - 4) / 2,
              bottomLeading: 0,
              bottomTrailing: 0,
              topTrailing: 0
            )
            imageCell(
              index: 1,
              width: (geometry.size.width - 4) / 2,
              height: (geometry.size.height - 4) / 2,
              topLeading: 0,
              bottomLeading: 0,
              bottomTrailing: 0
            )
          }
          HStack(spacing: 4) {
            imageCell(
              index: 2,
              width: (geometry.size.width - 4) / 2,
              height: (geometry.size.height - 4) / 2,
              topLeading: 0,
              bottomTrailing: 0,
              topTrailing: 0
            )
            ZStack {
              imageCell(
                index: 3,
                width: (geometry.size.width - 4) / 2,
                height: (geometry.size.height - 4) / 2,
                topLeading: 0,
                bottomLeading: 0,
                topTrailing: 0
              )
              if images.count > 4 {
                Color.black.opacity(0.6)
                  .clipShape(
                    .rect(
                      bottomTrailingRadius: 6
                    )
                  )
                Text("+\(images.count - 4)")
                  .font(.system(size: 22, weight: .bold))
                  .foregroundColor(.white)
              }
            }
            .onTapGesture {
              selectedImageIndex = 3
            }
          }
        }
      }
    }
    .aspectRatio(contentMode: .fit)
  }

  private func imageCell(
    index: Int,
    width: CGFloat,
    height: CGFloat,
    topLeading: CGFloat = 6,
    bottomLeading: CGFloat = 6,
    bottomTrailing: CGFloat = 6,
    topTrailing: CGFloat = 6
  ) -> some View {
    Group {
      if index < images.count, let url = URL(string: images[index].imageBlobUrl)
      {
        LazyImage(url: url) {
          state in
          if let image = state.image {
            image.resizable()
          } else {
            ProgressView()
              .frame(maxWidth: .infinity, maxHeight: .infinity)
              #if os(macOS)
                .controlSize(.small)
              #endif
          }
        }
        .processors([.resize(width: screenWidth)])
        .aspectRatio(contentMode: .fill)
        .frame(width: width, height: height)
        .clipShape(
          .rect(
            topLeadingRadius: topLeading,
            bottomLeadingRadius: bottomLeading,
            bottomTrailingRadius: bottomTrailing,
            topTrailingRadius: topTrailing
          )
        )
        .contentShape(.rect)
        .modifier(
          TransitionSourceModifier(id: "image-\(index)", namespace: animation)
        )
        .onTapGesture {
          selectedImageIndex = index
        }
      }
    }
  }

  private var screenWidth: CGFloat {
    #if os(iOS)
      return UIScreen.main.bounds.width
    #else
      return min(NSScreen.main?.frame.width ?? 400, 600)
    #endif
  }

  private func singleImageCell() -> some View {
    Group {
      if let url = URL(string: images[0].imageBlobUrl) {
        let image = images[0]
        let aspectRatio = CGFloat(image.width) / CGFloat(image.height)
        let isVeryWide = aspectRatio > 2.5
        let isVeryTall = aspectRatio < 0.4
        let displayWidth = screenWidth - 32
        let expectedHeight = displayWidth / aspectRatio
        let frameHeight: CGFloat? = isVeryTall ? 500 : isVeryWide ? 200 : nil

        LazyImage(url: url) {
          state in
          if let image = state.image {
            image.resizable()
          } else {
            ProgressView()
              .frame(
                maxWidth: .infinity,
                maxHeight: frameHeight ?? expectedHeight
              )
          }
        }
        .processors([.resize(width: screenWidth)])
        .aspectRatio(
          aspectRatio,
          contentMode: (isVeryWide || isVeryTall) ? .fill : .fit
        )
        .frame(height: frameHeight)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(.rect)
        .modifier(TransitionSourceModifier(id: "image-0", namespace: animation))
        .onTapGesture {
          selectedImageIndex = 0
        }
      }
    }
  }
}

struct ImageItem: Identifiable {
  let id: Int
  let url: URL
}

#Preview("Single Image") {
  let images = [
    ImageDTO(
      imageId: 1,
      postId: 1,
      height: 800,
      width: 600,
      imageBlobUrl:
        "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
      displayOrder: 0
    )
  ]

  Rectangle().frame(height: 10)
  ImageGallery(images: images)
  Rectangle().frame(height: 10)
}

#Preview("2 Images") {
  let images = [
    ImageDTO(
      imageId: 1,
      postId: 1,
      height: 800,
      width: 600,
      imageBlobUrl:
        "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
      displayOrder: 0
    ),
    ImageDTO(
      imageId: 2,
      postId: 1,
      height: 600,
      width: 800,
      imageBlobUrl:
        "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
      displayOrder: 1
    ),
  ]

  Rectangle().frame(height: 10)
  ImageGallery(images: images)
  Rectangle().frame(height: 10)
}

#Preview("3 Images") {
  let images = [
    ImageDTO(
      imageId: 1,
      postId: 1,
      height: 800,
      width: 600,
      imageBlobUrl:
        "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
      displayOrder: 0
    ),
    ImageDTO(
      imageId: 2,
      postId: 1,
      height: 600,
      width: 800,
      imageBlobUrl:
        "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
      displayOrder: 1
    ),
    ImageDTO(
      imageId: 3,
      postId: 1,
      height: 800,
      width: 600,
      imageBlobUrl:
        "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
      displayOrder: 2
    ),
  ]

  Rectangle().frame(height: 10)
  ImageGallery(images: images)
  Rectangle().frame(height: 10)
}

#Preview("4 Images") {
  let images = [
    ImageDTO(
      imageId: 1,
      postId: 1,
      height: 800,
      width: 600,
      imageBlobUrl:
        "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
      displayOrder: 0
    ),
    ImageDTO(
      imageId: 2,
      postId: 1,
      height: 600,
      width: 800,
      imageBlobUrl:
        "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
      displayOrder: 1
    ),
    ImageDTO(
      imageId: 3,
      postId: 1,
      height: 800,
      width: 600,
      imageBlobUrl:
        "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
      displayOrder: 2
    ),
    ImageDTO(
      imageId: 4,
      postId: 1,
      height: 600,
      width: 800,
      imageBlobUrl:
        "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
      displayOrder: 3
    ),
  ]

  Rectangle().frame(height: 10)
  ImageGallery(images: images)
  Rectangle().frame(height: 10)
}

#Preview("5 Images") {
  let images = [
    ImageDTO(
      imageId: 1,
      postId: 1,
      height: 800,
      width: 600,
      imageBlobUrl:
        "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
      displayOrder: 0
    ),
    ImageDTO(
      imageId: 2,
      postId: 1,
      height: 600,
      width: 800,
      imageBlobUrl:
        "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
      displayOrder: 1
    ),
    ImageDTO(
      imageId: 3,
      postId: 1,
      height: 800,
      width: 600,
      imageBlobUrl:
        "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
      displayOrder: 2
    ),
    ImageDTO(
      imageId: 4,
      postId: 1,
      height: 600,
      width: 800,
      imageBlobUrl:
        "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
      displayOrder: 3
    ),
    ImageDTO(
      imageId: 5,
      postId: 1,
      height: 800,
      width: 600,
      imageBlobUrl:
        "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
      displayOrder: 4
    ),
  ]

  Rectangle().frame(height: 10)
  ImageGallery(images: images)
  Rectangle().frame(height: 10)
}

#Preview("Wide Image") {
  let images = [
    ImageDTO(
      imageId: 1,
      postId: 1,
      height: 400,
      width: 1200,
      imageBlobUrl:
        "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/6/59041497-5dfa-4a8d-b87d-7745bb59f953.jpg",
      displayOrder: 0
    )
  ]

  Rectangle().frame(height: 10)
  ImageGallery(images: images)
  Rectangle().frame(height: 10)
}
