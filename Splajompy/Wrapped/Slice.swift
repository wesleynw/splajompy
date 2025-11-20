import SwiftUI

struct UserProportionRing: View {
    let userPercent: Double
    let ringWidthRatio: CGFloat = 0.05
    let gapDegrees: Double = 9
    @State private var isShowingIntroText: Bool = true
    @State private var isShowingPercentage: Bool = false
    @State private var animatedUserPercent: Double = 0
    @State private var isAnimatingToCenter: Bool = false

    var body: some View {
        VStack {
            if isAnimatingToCenter {
                Text("Your slice of Splajompy")
                    .fontWeight(.bold)
                    .font(.title)
                    .padding()
            }
            if isShowingIntroText {
                Text("What % of Splajompy are you?")
                    .fontWeight(.bold)
                    .font(.title2)
            } else {
                rings
                    .padding()
            }
        }
        .frame(maxHeight: .infinity)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                withAnimation { isShowingIntroText = false }

            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation(.bouncy(duration: 1.7)) {
                    animatedUserPercent = userPercent
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
                withAnimation(.default) {
                    isShowingPercentage = true
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button("Continue") {
                withAnimation(.spring) {
                    isAnimatingToCenter.toggle()
                }
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
            .padding()
        }
    }

    @ViewBuilder
    private var rings: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let arcMidpoint = (animatedUserPercent / 100 * 360) / 2
            let chunkRotation = isAnimatingToCenter ? -arcMidpoint : 0

            let approximateWidth = .pi * size * animatedUserPercent / 100
            let approximateHeight = size * ringWidthRatio * 0.8

            // if it's a really small percentage, we need to override the ring width when zoomed
            // in or we'll just have a tall skinny slice
            let needsHeightOverride: Bool =
                approximateHeight / approximateWidth > 2 && isAnimatingToCenter
            let ringWidth =
                needsHeightOverride ? approximateWidth : size * ringWidthRatio

            let targetScale =
                isAnimatingToCenter
                ? size
                    / max(
                        approximateWidth,
                        needsHeightOverride
                            ? approximateWidth : approximateHeight
                    ) * 0.85 : 1.0

            let offsetY = isAnimatingToCenter ? size / 2 : 0

            ZStack {
                VStack {
                    Text("size: \(size)")
                    Text("width: \(approximateWidth)")
                }
                AnimatedRingSegment(
                    isHighlightedSlice: false,
                    startPercent: animatedUserPercent,
                    endPercent: 100,
                    showGap: animatedUserPercent != 0,
                    ringWidth: ringWidth,
                    gapDegrees: gapDegrees
                )
                .fill(.gray.opacity(0.3).gradient)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                .opacity(isAnimatingToCenter ? 0 : 1)
                .drawingGroup()

                AnimatedRingSegment(
                    isHighlightedSlice: true,
                    startPercent: 0,
                    endPercent: animatedUserPercent,
                    showGap: animatedUserPercent != 0,
                    ringWidth: ringWidth,
                    gapDegrees: gapDegrees
                )
                .fill(.blue.gradient)
                .shadow(color: .blue.opacity(0.4), radius: 6, x: 0, y: 3)
                .rotationEffect(.degrees(chunkRotation))

                //                if isShowingPercentage && !isAnimatingToCenter {
                //                    Text("\(animatedUserPercent, specifier: "%.1f")%")
                //                        .font(.title)
                //                        .fontWeight(.black)
                //                }
            }
            .frame(width: size, height: size)
                        .position(
                x: geometry.size.width / 2,
                y: geometry.size.height / 2 + offsetY
            )
            .animation(.spring(duration: 0.2), value: offsetY)
            .scaleEffect(targetScale)
            .animation(.spring(duration: 1.0), value: targetScale)
            .transition(.scale.animation(.spring(duration: 5.2)))
        }
        .padding()
    }
}

struct AnimatedRingSegment: Shape {
    var isHighlightedSlice: Bool
    var startPercent: Double
    var endPercent: Double
    var showGap: Bool
    let ringWidth: CGFloat
    let gapDegrees: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(startPercent, endPercent) }
        set {
            startPercent = newValue.first
            endPercent = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius - ringWidth

        let gapScale: Double
        if showGap && !isHighlightedSlice {
            gapScale = min(startPercent / 5.0, 1.0)
        } else {
            gapScale = 0
        }

        let frontGap = gapDegrees * gapScale
        let backGap = gapDegrees * gapScale

        let startAngle = Angle(
            degrees: -90 + (startPercent / 100 * 360) + frontGap / 2
        )
        let endAngle = Angle(
            degrees: -90 + (endPercent / 100 * 360) - backGap / 2
        )

        var path = Path()
        path.addArc(
            center: center,
            radius: outerRadius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        path.addLine(
            to: CGPoint(
                x: center.x + innerRadius * cos(endAngle.radians),
                y: center.y + innerRadius * sin(endAngle.radians)
            )
        )
        path.addArc(
            center: center,
            radius: innerRadius,
            startAngle: endAngle,
            endAngle: startAngle,
            clockwise: true
        )
        path.closeSubpath()

        return path
    }
}

#Preview {
    UserProportionRing(userPercent: 2)
}
