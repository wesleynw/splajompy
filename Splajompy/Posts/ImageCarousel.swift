import SwiftUI

struct ImageCarousel: View {
    let imageUrls: [String]
    
    @State private var currentIndex: Int = 0
    @State private var dragOffset: CGFloat = 0
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 12) { 
                TabView(selection: $currentIndex) {
                    ForEach(0..<imageUrls.count, id: \.self) { index in
                        if let url = URL(string: "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/" + imageUrls[index]) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                        .frame(width: geometry.size.width, height: geometry.size.width)
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: geometry.size.width, height: geometry.size.width)
                                        .clipped()
                                case .failure:
                                    Color.gray
                                        .frame(width: geometry.size.width, height: geometry.size.width)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            .tag(index)
                        }
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .frame(width: geometry.size.width, height: geometry.size.width)
                
                HStack(spacing: 8) {
                    ForEach(0..<imageUrls.count, id: \.self) { index in
                        Circle()
                            .fill(currentIndex == index ?
                                  (colorScheme == .dark ? Color.white : Color.black) :
                                  (colorScheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.5)))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.top, 4)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

struct ImageCarousel_Preview: PreviewProvider {
    static var previews: some View {
        PostView(
            post: Post(
                PostID: 123,
                Text: "This is a sample post with some text content that might span multiple lines in the UI.",
                CreatedAt: "2025-03-25 10:19:20",
                UserID: 5,
                Username: "wesleynw",
                Name: "Wesley",
                Commentcount: 5,
                Liked: false,
                Images: [
                    ImageDTO(
                        ImageID: 220,
                        PostID: 536,
                        Height: 130,
                        Width: 98,
                        ImageBlobUrl: "development/posts/1/c19201ac-ca86-4abf-a7fe-205d6bb7f92a.png",
                        DisplayOrder: 5
                    ),
                    ImageDTO(
                        ImageID: 220,
                        PostID: 536,
                        Height: 130,
                        Width: 98,
                        ImageBlobUrl: "development/posts/1/e8acd749-9bf5-4e3a-993d-a50453108bbb.png",
                        DisplayOrder: 5
                    ),
                    ImageDTO(
                        ImageID: 220,
                        PostID: 536,
                        Height: 130,
                        Width: 98,
                        ImageBlobUrl: "development/posts/1/c19201ac-ca86-4abf-a7fe-205d6bb7f92a.png",
                        DisplayOrder: 5
                    )
                ]
                
            )
        ).previewLayout(.sizeThatFits)
    }
}
