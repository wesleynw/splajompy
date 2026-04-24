import Nuke
import PostHog
import SwiftUI

struct ImagePager: View {
  let imageUrls: [String]
  @State private var currentIndex: Int
  @State private var isToolbarDismissed: Bool = false

  let onDismiss: () -> Void
  let namespace: Namespace.ID

  init(
    imageUrls: [String],
    initialIndex: Int,
    onDismiss: @escaping () -> Void,
    namespace: Namespace.ID
  ) {
    self.imageUrls = imageUrls
    self._currentIndex = State(initialValue: initialIndex)
    self.onDismiss = onDismiss
    self.namespace = namespace
  }

  var body: some View {
    Group {
      ZStack {
        ZoomableAsyncImageMac(imageUrl: imageUrls[currentIndex])
          .id(currentIndex)
          .edgesIgnoringSafeArea(.all)

        if imageUrls.count > 1 {
          HStack {
            Button {
              withAnimation { currentIndex -= 1 }
            } label: {
              Image(systemName: "chevron.left")
                .font(.title)
                .padding()
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.leftArrow, modifiers: [])
            .disabled(currentIndex == 0)

            Spacer()

            Button {
              withAnimation { currentIndex += 1 }
            } label: {
              Image(systemName: "chevron.right")
                .font(.title)
                .padding()
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.rightArrow, modifiers: [])
            .disabled(currentIndex == imageUrls.count - 1)
          }
          .padding(.horizontal)
        }
      }
    }
    .ignoresSafeArea()
    .modifier(
      NavigationTransitionModifier(
        sourceID: "image-\(currentIndex)",
        namespace: namespace
      )
    )
  }
}

#Preview("Fullscreen Images") {
  @Previewable @Namespace var previewAnimation

  let imageUrls = [
    "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/production/6/comment/11713/4b5d1415-3a84-4acd-884f-3b4233993880.jpg?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Checksum-Mode=ENABLED&X-Amz-Credential=DO00R7A3VXT8XKRVG3JT%2F20260422%2Fnyc3%2Fs3%2Faws4_request&X-Amz-Date=20260422T193143Z&X-Amz-Expires=86400&X-Amz-SignedHeaders=host&x-id=GetObject&X-Amz-Signature=b71155b0076b65aae03ca224798d02cccb764bcf7681d3d92b67e82a9600f68f",
    "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
    "https://splajompy-bucket.nyc3.cdn.digitaloceanspaces.com/development/posts/1/9278fc8a-401b-4145-83bb-ef05d4d52632.jpeg",
  ]

  ImagePager(
    imageUrls: imageUrls,
    initialIndex: 0,
    onDismiss: { print("dismiss") },
    namespace: previewAnimation
  )
}
