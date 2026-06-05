import PostHog
import SwiftUI

struct ImageLayoutOnboardingView: View {
  var onComplete: () -> Void
  @Binding var preference: ImageLayoutPreference
  @State private var currentSelection: ImageLayoutPreference = .carousel

  var body: some View {
    ScrollView {
      VStack {
        VStack(spacing: 6) {
          Text("Answer us.")
            .font(.title)
            .fontWeight(.bold)
          Text(
            "Splajompy implores you to choose your preferred way to view images."
          )
          .foregroundStyle(.secondary)
          .padding()
        }
        .multilineTextAlignment(.center)
        .padding()

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
    .safeAreaInset(edge: .bottom) {
      Button {
        PostHogSDK.shared.register([
          "image_layout_preference": currentSelection.rawValue
        ])
        preference = currentSelection
        onComplete()
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
  }

  private struct CarouselPreview: View {
    private let maxHeight: CGFloat = 300
    private let cardHeight: CGFloat = 260

    var body: some View {
      GeometryReader { geometry in
        let maxWidth = geometry.size.width
        let narrow = min(maxWidth, cardHeight * (2.0 / 3))
        let medium = min(maxWidth, cardHeight * 1.0)
        let wide = min(maxWidth, cardHeight * (4.0 / 3)) - 16

        ScrollView(.horizontal) {
          HStack(alignment: .center) {
            RoundedRectangle(cornerRadius: 12).fill(Color.green.gradient).frame(
              width: narrow,
              height: cardHeight
            )
            RoundedRectangle(cornerRadius: 12).fill(Color.blue.gradient).frame(
              width: medium,
              height: cardHeight
            )
            RoundedRectangle(cornerRadius: 12).fill(Color.red.gradient).frame(
              width: wide,
              height: cardHeight
            )
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
          RoundedRectangle(cornerRadius: 12).fill(Color.green.gradient).frame(
            width: halfWidth,
            height: size
          )
          VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 12).fill(Color.blue.gradient).frame(
              width: halfWidth,
              height: halfHeight
            )
            RoundedRectangle(cornerRadius: 12).fill(Color.red.gradient).frame(
              width: halfWidth,
              height: halfHeight
            )
          }
        }
      }
      .aspectRatio(1, contentMode: .fit)
    }
  }
}
