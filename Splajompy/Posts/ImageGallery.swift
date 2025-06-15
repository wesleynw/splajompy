import Kingfisher
import SwiftUI

struct ImageGallery: View {
  let imageUrls: [String]

  @State private var selectedImageIndex: Int? = nil
  @Environment(\.colorScheme) var colorScheme

  private let imageSpacing: CGFloat = 4
  private let cornerRadius: CGFloat = 6

  var body: some View {
    Group {
      if imageUrls.isEmpty {
        EmptyView()
      } else if imageUrls.count == 1 {
        singleImageCell()
      } else {
        multipleImagesLayout()
      }
    }
    .fullScreenCover(
      item: Binding<ImageItem?>(
        get: {
          guard let index = selectedImageIndex, index < imageUrls.count else {
            return nil
          }
          return ImageItem(id: index, url: URL(string: imageUrls[index])!)
        },
        set: { selectedImageIndex = $0?.id }
      )
    ) { imageItem in
      FullscreenImagePager(
        imageUrls: imageUrls,
        initialIndex: imageItem.id,
        onDismiss: { selectedImageIndex = nil }
      )
    }
  }

  private func multipleImagesLayout() -> some View {
    GeometryReader { geometry in
      if imageUrls.count == 2 {
        twoImagesLayout(geometry: geometry)
      } else if imageUrls.count == 3 {
        threeImagesLayout(geometry: geometry)
      } else {
        fourPlusImagesLayout(geometry: geometry)
      }
    }
    .aspectRatio(contentMode: .fit)
    .drawingGroup()
  }

  private func twoImagesLayout(geometry: GeometryProxy) -> some View {
    HStack(spacing: imageSpacing) {
      optimizedImageCell(
        index: 0,
        width: (geometry.size.width - imageSpacing) / 2,
        height: geometry.size.height,
        topLeading: true,
        bottomLeading: true
      )
      optimizedImageCell(
        index: 1,
        width: (geometry.size.width - imageSpacing) / 2,
        height: geometry.size.height,
        topTrailing: true,
        bottomTrailing: true
      )
    }
  }

  private func threeImagesLayout(geometry: GeometryProxy) -> some View {
    HStack(spacing: imageSpacing) {
      optimizedImageCell(
        index: 0,
        width: (geometry.size.width - imageSpacing) / 2,
        height: geometry.size.height,
        topLeading: true,
        bottomLeading: true
      )

      VStack(spacing: imageSpacing) {
        optimizedImageCell(
          index: 1,
          width: (geometry.size.width - imageSpacing) / 2,
          height: (geometry.size.height - imageSpacing) / 2,
          topTrailing: true
        )
        optimizedImageCell(
          index: 2,
          width: (geometry.size.width - imageSpacing) / 2,
          height: (geometry.size.height - imageSpacing) / 2,
          bottomTrailing: true
        )
      }
    }
  }

  private func fourPlusImagesLayout(geometry: GeometryProxy) -> some View {
    VStack(spacing: imageSpacing) {
      HStack(spacing: imageSpacing) {
        optimizedImageCell(
          index: 0,
          width: (geometry.size.width - imageSpacing) / 2,
          height: (geometry.size.height - imageSpacing) / 2,
          topLeading: true
        )
        optimizedImageCell(
          index: 1,
          width: (geometry.size.width - imageSpacing) / 2,
          height: (geometry.size.height - imageSpacing) / 2,
          topTrailing: true
        )
      }

      HStack(spacing: imageSpacing) {
        optimizedImageCell(
          index: 2,
          width: (geometry.size.width - imageSpacing) / 2,
          height: (geometry.size.height - imageSpacing) / 2,
          bottomLeading: true
        )

        ZStack {
          optimizedImageCell(
            index: 3,
            width: (geometry.size.width - imageSpacing) / 2,
            height: (geometry.size.height - imageSpacing) / 2,
            bottomTrailing: true
          )

          if imageUrls.count > 4 {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
              .fill(Color.black.opacity(0.6))
              .overlay(
                Text("+\(imageUrls.count - 4)")
                  .font(.system(size: 22, weight: .bold))
                  .foregroundColor(.white)
              )
          }
        }
        .onTapGesture {
          selectedImageIndex = 3
        }
      }
    }
  }

  private func optimizedImageCell(
    index: Int,
    width: CGFloat,
    height: CGFloat,
    topLeading: Bool = false,
    topTrailing: Bool = false,
    bottomLeading: Bool = false,
    bottomTrailing: Bool = false
  ) -> some View {
    Group {
      if index < imageUrls.count, let url = URL(string: imageUrls[index]) {
        KFImage(url)
          .fade(duration: 0.1)
          .placeholder {
            Rectangle()
              .fill(Color.gray.opacity(0.3))
              .frame(width: width, height: height)
              .overlay {
                CustomProgressIndicator()
                  .scaleEffect(0.8)
              }
          }
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(width: width, height: height)
          .clipped()
          .clipShape(
            .rect(
              topLeadingRadius: topLeading ? cornerRadius : 0,
              bottomLeadingRadius: bottomLeading ? cornerRadius : 0,
              bottomTrailingRadius: bottomTrailing ? cornerRadius : 0,
              topTrailingRadius: topTrailing ? cornerRadius : 0
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
      if let url = URL(string: imageUrls[0]) {
        KFImage(url)
          .fade(duration: 0.1)
          .placeholder {
            Rectangle()
              .fill(Color.gray.opacity(0.3))
              .aspectRatio(4 / 3, contentMode: .fit)
              .overlay {
                CustomProgressIndicator()
                  .scaleEffect(1.2)
              }
          }
          .resizable()
          .aspectRatio(contentMode: .fit)
          .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
          .contentShape(Rectangle())
          .onTapGesture {
            selectedImageIndex = 0
          }
      } else {
        Color.clear
      }
    }
  }
}

struct CustomProgressIndicator: View {
  @State private var rotation: Double = 0

  var body: some View {
    Circle()
      .trim(from: 0, to: 0.7)
      .stroke(Color.gray, lineWidth: 2)
      .frame(width: 20, height: 20)
      .rotationEffect(.degrees(rotation))
      .onAppear {
        withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
          rotation = 360
        }
      }
  }
}

extension View {
  @ViewBuilder
  func conditionalDrawingGroup(_ condition: Bool) -> some View {
    if condition {
      self.drawingGroup()
    } else {
      self
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
  let imageUrls = [
    "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg"
  ]

  Rectangle().frame(height: 10)
  ImageGallery(imageUrls: imageUrls)
  Rectangle().frame(height: 10)
}

#Preview("2 Images") {
  let imageUrls = [
    "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
    "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
  ]

  Rectangle().frame(height: 10)
  ImageGallery(imageUrls: imageUrls)
  Rectangle().frame(height: 10)
}

#Preview("3 Images") {
  let imageUrls = [
    "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
    "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
    "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
  ]

  Rectangle().frame(height: 10)
  ImageGallery(imageUrls: imageUrls)
  Rectangle().frame(height: 10)
}

#Preview("4 Images") {
  let imageUrls = [
    "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
    "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
    "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
    "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
  ]

  Rectangle().frame(height: 10)
  ImageGallery(imageUrls: imageUrls)
  Rectangle().frame(height: 10)
}

#Preview("5 Images") {
  let imageUrls = [
    "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
    "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
    "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
    "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
    "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
  ]

  Rectangle().frame(height: 10)
  ImageGallery(imageUrls: imageUrls)
  Rectangle().frame(height: 10)
}

#Preview("Wide Image") {
  let imageUrls = [
    "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/6/59041497-5dfa-4a8d-b87d-7745bb59f953.jpg"
  ]

  Rectangle().frame(height: 10)
  ImageGallery(imageUrls: imageUrls)
  Rectangle().frame(height: 10)
}
