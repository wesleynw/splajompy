import SwiftUI

enum ImageLayoutPreference: String {
  case undecided
  case grid
  case carousel
}

struct ImageLayoutOnboardingViewModifier: ViewModifier {
  @AppStorage("image_layout_preference") private var imageLayoutPreference:
    ImageLayoutPreference = .undecided

  func body(content: Content) -> some View {
    content
      .sheet(isPresented: .constant(imageLayoutPreference == .undecided)) {
        OnboardingView()
          .interactiveDismissDisabled()
      }
  }

  private struct OnboardingView: View {
    @State private var currentSelection: ImageLayoutPreference = .carousel

    var body: some View {
      ScrollView {
        VStack {
          Text(
            "Splajompy implores you to chose your preferred way to view images in posts."
          )
          .padding()
          .font(.title3)
          .fontWeight(.semibold)
          .multilineTextAlignment(.center)
          .foregroundStyle(.secondary)

          ZStack {
            CarouselPreview()
              .opacity(currentSelection == .carousel ? 1 : 0)
              .blur(radius: currentSelection == .carousel ? 0 : 8)
            GridPreview()
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
    }
  }

  private struct CarouselPreview: View {
    private let maxHeight: CGFloat = 300
    private let cardHeight: CGFloat = 260

    var body: some View {
      GeometryReader { geometry in
        let maxWidth = geometry.size.width
        ScrollView(.horizontal) {
          HStack(alignment: .center) {
            DitheredCard(color: .green, width: maxWidth * 0.4, height: cardHeight)
            DitheredCard(color: .blue,  width: maxWidth * 0.7, height: cardHeight)
            DitheredCard(color: .red,   width: maxWidth * 0.6, height: cardHeight)
//            RoundedRectangle(cornerRadius: 12)
//              .fill(.green.gradient)
//              .frame(width: maxWidth * 0.4, height: cardHeight)
//            RoundedRectangle(cornerRadius: 12)
//              .fill(.blue.gradient)
//              .frame(width: maxWidth * 0.7, height: cardHeight)
//            RoundedRectangle(cornerRadius: 12)
//              .fill(.red.gradient)
//              .frame(width: maxWidth * 0.6, height: cardHeight)
          }
          .frame(height: maxHeight)  
        }
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .scrollIndicators(.hidden)
      }
      .frame(height: maxHeight)
    }
  }

  private struct GridPreview: View {
    var body: some View {
      GeometryReader { geometry in
        let size = geometry.size.width
        let halfWidth = (size - 4) / 2
        let halfHeight = (size - 4) / 2

        HStack(spacing: 4) {
          RoundedRectangle(cornerRadius: 12)
            .fill(.green.gradient)
            .frame(width: halfWidth, height: size)
          VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 12)
              .fill(.blue.gradient)
              .frame(width: halfWidth, height: halfHeight)
            RoundedRectangle(cornerRadius: 12)
              .fill(.red.gradient)
              .frame(width: halfWidth, height: halfHeight)
          }
        }
      }
      .aspectRatio(1, contentMode: .fit)
    }
  }
}

#Preview {
  Color.clear
    .modifier(ImageLayoutOnboardingViewModifier())
}
