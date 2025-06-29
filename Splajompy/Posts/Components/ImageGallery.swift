import Kingfisher
import SwiftUI

struct ImageGallery: View {
  let images: [ImageDTO]

  @State private var selectedImageIndex: Int? = nil
  @Environment(\.colorScheme) var colorScheme

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
    .fullScreenCover(
      item: Binding<ImageItem?>(
        get: {
          guard let index = selectedImageIndex, index < images.count else {
            return nil
          }
          return ImageItem(id: index, url: URL(string: images[index].imageBlobUrl)!)
        },
        set: { selectedImageIndex = $0?.id }
      )
    ) { imageItem in
      FullscreenImagePager(
        imageUrls: images.map { $0.imageBlobUrl },
        initialIndex: imageItem.id,
        onDismiss: { selectedImageIndex = nil }
      )
    }
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
      if index < images.count, let url = URL(string: images[index].imageBlobUrl) {
        OptimizedKFImage(
          url,
          contentMode: .fill,
          targetSize: CGSize(width: width, height: height)
        )
        .frame(width: width, height: height)
        .clipped()
        .clipShape(
          .rect(
            topLeadingRadius: topLeading,
            bottomLeadingRadius: bottomLeading,
            bottomTrailingRadius: bottomTrailing,
            topTrailingRadius: topTrailing
          )
        )
        .contentShape(Rectangle())
        .onTapGesture {
          selectedImageIndex = index
        }
      }
    }
  }

  private func singleImageCell() -> some View {
    Group {
      if let url = URL(string: images[0].imageBlobUrl) {
        let aspectRatio = CGFloat(images[0].width) / CGFloat(images[0].height)
        let containerWidth = UIScreen.main.bounds.width - 32 // Account for padding
        let calculatedHeight = containerWidth / aspectRatio
        
        OptimizedKFImage(url, contentMode: .fit)
          .frame(height: calculatedHeight)
          .clipShape(.rect(cornerRadius: 6))
          .onTapGesture {
            selectedImageIndex = 0
          }
      } else {
        Color.clear
      }
    }
  }
}

struct ImageItem: Identifiable {
  let id: Int
  let url: URL
}

struct FullscreenImagePager: View {
  let imageUrls: [String]
  @State private var currentIndex: Int
  let onDismiss: () -> Void

  init(imageUrls: [String], initialIndex: Int, onDismiss: @escaping () -> Void) {
    self.imageUrls = imageUrls
    self._currentIndex = State(initialValue: initialIndex)
    self.onDismiss = onDismiss
  }

  var body: some View {
    ZStack {
      TabView(selection: $currentIndex) {
        ForEach(Array(imageUrls.enumerated()), id: \.1) { index, url in
          if let url = URL(string: url) {
            KFImage(url)
              .resizable()
              .scaledToFit()
              .tag(index)
              .zoomable(minZoomScale: 1, doubleTapZoomScale: 2)
          }
        }
      }
      .tabViewStyle(PageTabViewStyle())
      .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))

      VStack {
        HStack {
          Text("\(currentIndex + 1) / \(imageUrls.count)")
            .foregroundColor(.white)
            .font(.subheadline)
            .fontWeight(.bold)
            .padding(8)
            .background(Color.black.opacity(0.6))
            .cornerRadius(8)
            .padding()
          Spacer()
          Button(action: onDismiss) {
            Image(systemName: "xmark")
              .font(.system(size: 20, weight: .bold))
              .foregroundColor(.white)
              .padding(12)
              .background(Color.black.opacity(0.6))
              .clipShape(Circle())
          }
          .padding()
        }
        Spacer()
      }
    }
    .gesture(
      DragGesture(minimumDistance: 10)
        .onEnded { gesture in
          if gesture.translation.height > 0 {
            onDismiss()
          }
        }
    )
  }
}

#Preview("Fullscreen Images") {
  let imageUrls = [
    "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
    "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
    "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
  ]

  FullscreenImagePager(
    imageUrls: imageUrls,
    initialIndex: 0,
    onDismiss: { print("dismiss") }
  )
}

#Preview("Single Image") {
  let images = [
    ImageDTO(
      imageId: 1,
      postId: 1,
      height: 800,
      width: 600,
      imageBlobUrl: "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
      displayOrder: 0
    )
  ]

  Rectangle().frame(height: 10)
  ImageGallery(images: images)
  Rectangle().frame(height: 10)
}

#Preview("2 Images") {
  let images = [
    ImageDTO(imageId: 1, postId: 1, height: 800, width: 600, imageBlobUrl: "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg", displayOrder: 0),
    ImageDTO(imageId: 2, postId: 1, height: 600, width: 800, imageBlobUrl: "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg", displayOrder: 1)
  ]

  Rectangle().frame(height: 10)
  ImageGallery(images: images)
  Rectangle().frame(height: 10)
}

#Preview("3 Images") {
  let images = [
    ImageDTO(imageId: 1, postId: 1, height: 800, width: 600, imageBlobUrl: "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg", displayOrder: 0),
    ImageDTO(imageId: 2, postId: 1, height: 600, width: 800, imageBlobUrl: "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg", displayOrder: 1),
    ImageDTO(imageId: 3, postId: 1, height: 800, width: 600, imageBlobUrl: "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg", displayOrder: 2)
  ]

  Rectangle().frame(height: 10)
  ImageGallery(images: images)
  Rectangle().frame(height: 10)
}

#Preview("4 Images") {
  let images = [
    ImageDTO(imageId: 1, postId: 1, height: 800, width: 600, imageBlobUrl: "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg", displayOrder: 0),
    ImageDTO(imageId: 2, postId: 1, height: 600, width: 800, imageBlobUrl: "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg", displayOrder: 1),
    ImageDTO(imageId: 3, postId: 1, height: 800, width: 600, imageBlobUrl: "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg", displayOrder: 2),
    ImageDTO(imageId: 4, postId: 1, height: 600, width: 800, imageBlobUrl: "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg", displayOrder: 3)
  ]

  Rectangle().frame(height: 10)
  ImageGallery(images: images)
  Rectangle().frame(height: 10)
}

#Preview("5 Images") {
  let images = [
    ImageDTO(imageId: 1, postId: 1, height: 800, width: 600, imageBlobUrl: "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg", displayOrder: 0),
    ImageDTO(imageId: 2, postId: 1, height: 600, width: 800, imageBlobUrl: "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg", displayOrder: 1),
    ImageDTO(imageId: 3, postId: 1, height: 800, width: 600, imageBlobUrl: "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg", displayOrder: 2),
    ImageDTO(imageId: 4, postId: 1, height: 600, width: 800, imageBlobUrl: "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg", displayOrder: 3),
    ImageDTO(imageId: 5, postId: 1, height: 800, width: 600, imageBlobUrl: "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg", displayOrder: 4)
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
      imageBlobUrl: "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/6/59041497-5dfa-4a8d-b87d-7745bb59f953.jpg",
      displayOrder: 0
    )
  ]

  Rectangle().frame(height: 10)
  ImageGallery(images: images)
  Rectangle().frame(height: 10)
}
