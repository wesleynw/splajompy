import SwiftUI

struct ImageGallery: View {
  let imageUrls: [String]

  @State private var selectedImageIndex: Int? = nil
  @Environment(\.colorScheme) var colorScheme

  var baseURL = "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/"

  var body: some View {
    GeometryReader { geometry in
      if imageUrls.isEmpty {
        EmptyView()
      } else if imageUrls.count == 1 {
        if let url = URL(string: baseURL + imageUrls[0]) {
          AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
              ProgressView()
                .frame(
                  width: geometry.size.width,
                  height: geometry.size.width * 0.75
                )
            case .success(let image):
              image
                .resizable()
                .scaledToFit()
                .cornerRadius(10)
                .frame(width: geometry.size.width)
                .onTapGesture {
                  selectedImageIndex = 0
                }
            case .failure:
              Color.gray.opacity(0.3)
                .frame(
                  width: geometry.size.width,
                  height: geometry.size.width * 0.75
                )
                .cornerRadius(12)
                .overlay(
                  Image(systemName: "photo").font(.largeTitle).foregroundColor(
                    .gray
                  )
                )
            @unknown default:
              EmptyView()
            }
          }
        }
      } else if imageUrls.count == 2 {
        HStack(spacing: 4) {
          imageCell(
            index: 0,
            width: (geometry.size.width - 4) / 2,
            height: geometry.size.height,
            bottomTrailing: 0,
            topTrailing: 0,
          )

          imageCell(
            index: 1,
            width: (geometry.size.width - 4) / 2,
            height: geometry.size.height,
            topLeading: 0,
            bottomLeading: 0
          )
        }
      } else if imageUrls.count == 3 {
        HStack(spacing: 4) {
          imageCell(
            index: 0,
            width: (geometry.size.width - 4) / 2,
            height: geometry.size.height,
            bottomTrailing: 0,
            topTrailing: 0,
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
              index: 2,
              width: (geometry.size.width - 4) / 2,
              height: (geometry.size.height - 4) / 2,
              topLeading: 0,
              bottomLeading: 0,
              bottomTrailing: 0
            )
          }
          HStack(spacing: 4) {
            imageCell(
              index: 1,
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
              if imageUrls.count > 4 {
                Color.black.opacity(0.6)
                  .cornerRadius(6)
                Text("+\(imageUrls.count - 4)")
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
    .fullScreenCover(
      item: Binding<ImageItem?>(
        get: {
          if let index = selectedImageIndex {
            return ImageItem(
              id: index,
              url: URL(string: baseURL + imageUrls[index])!
            )
          }
          return nil
        },
        set: { selectedImageIndex = $0?.id }
      )
    ) { imageItem in
      FullscreenImagePager(
        imageUrls: imageUrls.map { baseURL + $0 },
        initialIndex: imageItem.id,
        onDismiss: { selectedImageIndex = nil }
      )
    }
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
      if let url = URL(string: baseURL + imageUrls[index]) {
        AsyncImage(url: url) { phase in
          switch phase {
          case .empty:
            ProgressView()
              .frame(width: width, height: height)
          case .success(let image):
            image
              .resizable()
              .aspectRatio(contentMode: .fill)
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
          case .failure:
            Color.gray.opacity(0.3)
              .frame(width: width, height: height)
              .cornerRadius(6)
              .overlay(
                Image(systemName: "photo").font(.title3).foregroundColor(.gray)
              )
          @unknown default:
            EmptyView()
              .frame(width: width, height: height)
          }
        }
        .onTapGesture {
          selectedImageIndex = index
        }
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
      //      Color.black.edgesIgnoringSafeArea(.all)

      TabView(selection: $currentIndex) {
        ForEach(0..<imageUrls.count, id: \.self) { index in
          if let url = URL(string: imageUrls[index]) {
            AsyncImage(url: url) { phase in
              switch phase {
              case .empty:
                ProgressView()
                  .foregroundColor(.white)
              case .success(let image):
                ZoomableScrollView {
                  image
                    .resizable()
                    .scaledToFit()
                    .edgesIgnoringSafeArea(.all)
                }
              case .failure:
                VStack {
                  Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                  Text("Failed to load image")
                }
                .foregroundColor(.white)
              @unknown default:
                EmptyView()
              }
            }
            .tag(index)
          }
        }
      }
      .tabViewStyle(PageTabViewStyle())

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
  }
}

struct ZoomableScrollView<Content: View>: View {
  let content: Content

  @State private var currentScale: CGFloat = 1.0
  @State private var previousScale: CGFloat = 1.0
  @State private var isAnimating: Bool = false

  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  var body: some View {
    GeometryReader { geometry in
      ScrollView([.horizontal, .vertical], showsIndicators: false) {
        content
          .frame(width: geometry.size.width, height: geometry.size.height)
          .scaleEffect(currentScale)
          .animation(
            isAnimating ? .spring(response: 0.3, dampingFraction: 0.7) : .none,
            value: currentScale
          )
          .gesture(
            MagnificationGesture()
              .onChanged { value in
                isAnimating = false
                let delta = value / previousScale
                previousScale = value

                currentScale = currentScale * delta
              }
              .onEnded { _ in
                previousScale = 1.0
                isAnimating = true

                // Bounce back if beyond limits
                if currentScale < 1.0 {
                  currentScale = 1.0
                } else if currentScale > 4.0 {
                  currentScale = 4.0
                }
              }
          )
          .onTapGesture(count: 2) {
            isAnimating = true
            if currentScale > 1.0 {
              currentScale = 1.0
            } else {
              currentScale = min(3.0, max(1.0, currentScale * 2.0))
            }
          }
      }
      .frame(width: geometry.size.width, height: geometry.size.height)
      .background(Color.clear)
    }
  }
}

#Preview("Fullscreen Images") {
  let imageUrls = [
    "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
    "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
    "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
  ]

  FullscreenImagePager(imageUrls: imageUrls, initialIndex: 0, onDismiss: { print("dismiss") })
}

#Preview("Single Image") {
  let imageUrls = [
    "development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg"
  ]

  Rectangle().frame(height: 10)
  ImageGallery(imageUrls: imageUrls)
  Rectangle().frame(height: 10)
}

#Preview("2 Images") {
  let imageUrls = [
    "development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
    "development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
  ]

  Rectangle().frame(height: 10)
  ImageGallery(imageUrls: imageUrls)
  Rectangle().frame(height: 10)
}

#Preview("3 Images") {
  let imageUrls = [
    "development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
    "development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
    "development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
  ]

  Rectangle().frame(height: 10)
  ImageGallery(imageUrls: imageUrls)
  Rectangle().frame(height: 10)
}

#Preview("4 Images") {
  let imageUrls = [
    "development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
    "development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
    "development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
    "development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
  ]

  Rectangle().frame(height: 10)
  ImageGallery(imageUrls: imageUrls)
  Rectangle().frame(height: 10)
}

#Preview("5 Images") {
  let imageUrls = [
    "development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
    "development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
    "development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
    "development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
    "development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
  ]

  Rectangle().frame(height: 10)
  ImageGallery(imageUrls: imageUrls)
  Rectangle().frame(height: 10)
}
