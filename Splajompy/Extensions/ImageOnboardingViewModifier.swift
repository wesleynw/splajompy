import SwiftUI

enum ImageLayoutPreference: String {
  case undecided
  case grid
  case carousel
}

struct ImageLayoutOnboardingViewModifier: ViewModifier {
  @AppStorage("image_layout_preference") private var imageLayoutPreference: ImageLayoutPreference =
    .undecided

  func body(content: Content) -> some View {
    content
      .sheet(isPresented: .constant(imageLayoutPreference == .undecided)) {
        OnboardingView(preference: $imageLayoutPreference)
          .interactiveDismissDisabled()
      }
  }

  private struct OnboardingView: View {
    @Binding var preference: ImageLayoutPreference
    @State private var currentSelection: ImageLayoutPreference = .carousel
    @State private var readyCount = 0

    private var allReady: Bool { readyCount >= 2 }

    var body: some View {
      ScrollView {
        VStack {
          VStack(spacing: 6) {
            Text("Answer us.")
              .font(.title)
              .fontWeight(.bold)
            Text("Splajompy implores you to choose your preferred way to view images.")
              .foregroundStyle(.secondary)
              .padding()
          }
          .multilineTextAlignment(.center)
          .padding()

          ZStack {
            CarouselPreview(onAllLoaded: { readyCount += 1 })
              .opacity(currentSelection == .carousel ? 1 : 0)
              .blur(radius: currentSelection == .carousel ? 0 : 8)
            GridPreview(onAllLoaded: { readyCount += 1 })
              .padding()
              .opacity(currentSelection == .grid ? 1 : 0)
              .blur(radius: currentSelection == .grid ? 0 : 8)
          }
          .frame(height: 300)
          .clipShape(RoundedRectangle(cornerRadius: 25))
          .overlay {
            RoundedRectangle(cornerRadius: 25)
              .strokeBorder(.secondary.opacity(0.5))
          }
          .animation(.easeInOut(duration: 0.3), value: currentSelection)

          Picker("Layout", selection: $currentSelection) {
            Text("Carousel").tag(ImageLayoutPreference.carousel)
            Text("Grid").tag(ImageLayoutPreference.grid)
          }
          .pickerStyle(.segmented)
          .padding()
        }
        .padding()
      }
      .safeAreaInset(edge: .bottom) {
        Button {
          preference = currentSelection
        } label: {
          Text("Save")
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
        }
        .controlSize(.large)
        .modify {
          if #available(iOS 26, *) {
            $0.buttonStyle(.glassProminent)
          } else {
            $0.buttonStyle(.borderedProminent)
          }
        }
        .padding()
      }
      .overlay {
        if !allReady {
          ZStack {
            Color(.systemBackground)
            ProgressView()
          }
          .ignoresSafeArea()
          .transition(.opacity)
        }
      }
      .animation(.easeInOut, value: allReady)
    }
  }

  private struct CarouselPreview: View {
    var onAllLoaded: (() -> Void)? = nil
    private let maxHeight: CGFloat = 300
    private let cardHeight: CGFloat = 260
    @State private var loadedCount = 0

    var body: some View {
      GeometryReader { geometry in
        let maxWidth = geometry.size.width
        let narrow = min(maxWidth, cardHeight * (2.0 / 3))
        let medium = min(maxWidth, cardHeight * 1.0)
        let wide = min(maxWidth, cardHeight * (4.0 / 3)) - 16

        ScrollView(.horizontal) {
          HStack(alignment: .center) {
            DitheredCard(color: .green, width: narrow, height: cardHeight, onLoaded: cardLoaded)
            DitheredCard(color: .blue, width: medium, height: cardHeight, onLoaded: cardLoaded)
            DitheredCard(color: .red, width: wide, height: cardHeight, onLoaded: cardLoaded)
          }
          .frame(height: maxHeight)
        }
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .scrollIndicators(.hidden)
      }
      .frame(height: maxHeight)
    }

    private func cardLoaded() {
      loadedCount += 1
      if loadedCount >= 3 { onAllLoaded?() }
    }
  }

  private struct GridPreview: View {
    var onAllLoaded: (() -> Void)? = nil
    @State private var loadedCount = 0

    var body: some View {
      GeometryReader { geometry in
        let size = geometry.size.width
        let halfWidth = (size - 4) / 2
        let halfHeight = (size - 4) / 2

        HStack(spacing: 4) {
          DitheredCard(color: .green, width: halfWidth, height: size, onLoaded: cardLoaded)
          VStack(spacing: 4) {
            DitheredCard(color: .blue, width: halfWidth, height: halfHeight, onLoaded: cardLoaded)
            DitheredCard(color: .red, width: halfWidth, height: halfHeight, onLoaded: cardLoaded)
          }
        }
      }
      .aspectRatio(1, contentMode: .fit)
    }

    private func cardLoaded() {
      loadedCount += 1
      if loadedCount >= 3 { onAllLoaded?() }
    }
  }
}

#Preview {
  Color.clear
    .modifier(ImageLayoutOnboardingViewModifier())
}
