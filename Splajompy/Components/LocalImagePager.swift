import SwiftUI

/// A fullscreen pager for images that are already loaded in memory (not yet uploaded),
/// e.g. images staged in the new post composer.
struct LocalImagePager: View {
  let images: [PlatformImage]
  @Binding var currentIndex: Int

  let onDismiss: () -> Void

  var body: some View {
    #if os(iOS)
      ZStack {
        TabView(selection: $currentIndex) {
          ForEach(Array(images.enumerated()), id: \.offset) { index, image in
            Image(platformImage: image)
              .resizable()
              .scaledToFit()
              .tag(index)
          }
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .ignoresSafeArea()

        pagerNavigationBar
      }
      .background(Color.black.ignoresSafeArea())
      .statusBarHidden()
    #else
      NavigationStack {
        ZStack {
          Image(platformImage: images[currentIndex])
            .resizable()
            .scaledToFit()
            .id(currentIndex)
            .edgesIgnoringSafeArea(.all)

          if images.count > 1 {
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
              .disabled(currentIndex == images.count - 1)
            }
            .padding(.horizontal)
          }
        }
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Close") {
              onDismiss()
            }
          }
        }
      }
    #endif
  }

  #if os(iOS)
    private var pagerNavigationBar: some View {
      VStack {
        HStack {
          if images.count > 1 {
            Text("\(currentIndex + 1) of \(images.count)")
              .padding(10)
              .font(.body.monospacedDigit())
              .foregroundStyle(.secondary)
              .modify {
                if #available(iOS 26, *) {
                  $0.glassEffect(.regular.interactive(), in: .capsule)
                } else {
                  $0.background(.thinMaterial, in: .capsule)
                }
              }
          }

          Spacer()

          Button(action: onDismiss) {
            Image(systemName: "xmark")
              .font(.title3)
              .frame(width: 20, height: 20)
          }
          .buttonBorderShape(.circle)
          .controlSize(.large)
          .fontWeight(.semibold)
          .modify {
            if #available(iOS 26, *) {
              $0.buttonStyle(.glass)
            } else {
              $0.buttonStyle(.bordered)
                .background(.thinMaterial, in: .circle)
            }
          }
        }
        .padding()

        Spacer()
      }
    }
  #endif
}

#Preview {
  let images: [PlatformImage] = {
    #if os(iOS)
      return [
        UIImage(systemName: "mountain.2.fill")!,
        UIImage(systemName: "photo.fill")!,
      ]
    #else
      return [
        NSImage(
          systemSymbolName: "mountain.2.fill",
          accessibilityDescription: nil
        )!,
        NSImage(
          systemSymbolName: "photo.fill",
          accessibilityDescription: nil
        )!,
      ]
    #endif
  }()

  LocalImagePager(images: images, currentIndex: .constant(0), onDismiss: {})
}
