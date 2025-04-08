import SwiftUI

struct ImageCarousel: View {
  let imageUrls: [String]
  @State private var currentIndex: Int = 0
  @State private var imageAspectRatios: [Int: CGFloat] = [:]
  @Environment(\.colorScheme) var colorScheme

  var body: some View {
    GeometryReader { geometry in
      VStack(spacing: 8) {
        TabView(selection: $currentIndex) {
          ForEach(0..<imageUrls.count, id: \.self) { index in
            if let url = URL(
              string: "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/" + imageUrls[index]
            ) {
              AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                  ProgressView()
                    .frame(width: geometry.size.width, height: geometry.size.width)
                case .success(let image):
                  image
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width)
                    .background(
                      GeometryReader { imageReader in
                        Color.clear.onAppear {
                          let aspectRatio = imageReader.size.width / imageReader.size.height
                          imageAspectRatios[index] = aspectRatio
                        }
                      })
                case .failure:
                  Color.gray.opacity(0.3)
                    .frame(width: geometry.size.width, height: geometry.size.width * 0.75)
                    .overlay(Image(systemName: "photo").font(.largeTitle).foregroundColor(.gray))
                @unknown default:
                  EmptyView()
                }
              }
              .tag(index)
            }
          }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .frame(width: geometry.size.width, height: carouselHeight(for: geometry))
        .clipped()

        if imageUrls.count > 1 {
          HStack(spacing: 6) {
            ForEach(0..<imageUrls.count, id: \.self) { index in
              Circle()
                .fill(
                  currentIndex == index
                    ? (colorScheme == .dark ? Color.white : Color.black)
                    : (colorScheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.5))
                )
                .frame(width: 6, height: 6)
            }
          }
        }
      }
    }
    .aspectRatio(contentMode: .fit)
  }

  private func carouselHeight(for geometry: GeometryProxy) -> CGFloat {
    guard let aspectRatio = imageAspectRatios[currentIndex], aspectRatio > 0 else {
      return geometry.size.width * 0.75  // default 4:3 aspect ratio
    }

    return geometry.size.width / aspectRatio
  }
}
