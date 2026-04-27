import DitheringEngine
import SwiftUI

@Observable
@MainActor
final class DitherCardModel {
    var image: UIImage?
    var isLoading = true
    private var rendered = false

    func renderIfNeeded(color: Color, width: CGFloat, height: CGFloat) {
        guard !rendered else { return }
        rendered = true
        Task {
            image = await Self.render(color: color, width: width, height: height)
            isLoading = false
        }
    }

    private static func render(color: Color, width: CGFloat, height: CGFloat) async -> UIImage? {
        let size = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: size)
        let uiColor = UIColor(color)
        let uiColorFaded = UIColor(color.opacity(0.4))
        let uiImage = renderer.image { ctx in
            let colors = [uiColor.cgColor, uiColorFaded.cgColor]
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: [0, 1]
            )!
            ctx.cgContext.drawLinearGradient(
                gradient,
                start: .zero,
                end: CGPoint(x: width, y: height),
                options: []
            )
        }
        guard let cgImage = uiImage.cgImage else { return nil }
        return await Task.detached(priority: .userInitiated) {
            let engine = DitheringEngine()
            try? engine.set(image: cgImage)
            guard let result = try? engine.dither(
                usingMethod: .bayer,
                andPalette: .quantizedColor,
                withDitherMethodSettings: BayerSettingsConfiguration(
                    thresholdMapSize: 8,
                    performOnCPU: false
                ),
                withPaletteSettings: QuantizedColorSettingsConfiguration(bits: 1)
            ) else { return nil }
            return UIImage(cgImage: result)
        }.value
    }
}

struct DitheredCard: View {
    let color: Color
    let width: CGFloat
    let height: CGFloat
    @State private var model = DitherCardModel()

    var body: some View {
        Group {
            if let image = model.image {
                Image(uiImage: image)
                    .resizable()
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.gradient)
                    .frame(width: width, height: height)
                    .overlay {
                        if model.isLoading {
                            ProgressView()
                                .tint(.white)
                        }
                    }
            }
        }
        .onAppear {
            model.renderIfNeeded(color: color, width: width, height: height)
        }
    }
}
