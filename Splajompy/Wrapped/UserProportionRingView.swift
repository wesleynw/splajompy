import SwiftUI

struct UserProportionRing: View {
  let data: WrappedData
  let ringWidthRatio: Float = 0.05
  let gapDegrees: Double = 9
  let onContinue: () -> Void

  @State private var isShowingIntroText: Bool = true
  @State private var isShowingPercentage: Bool = false
  @State private var animatedUserPercent: Double = 0
  @State private var isAnimatingToCenter: Bool = false
  @State private var showComponentBreakdown: Bool = false

  var body: some View {
    VStack {
      if isAnimatingToCenter {
        VStack {
          Text("Your slice of Splajompy")
            .fontDesign(.rounded)
            .fontWeight(.black)
            .font(.title)
            .padding()

          Text("\(data.sliceData.percent, specifier: "%.1f")%")
            .foregroundStyle(.blue.gradient)
            .fontWeight(.black)
            .font(.largeTitle)

          HStack {
            VStack {
              Text("\(data.sliceData.postComponent, specifier: "%.1f")%")
                .fontWeight(.black)
                .font(.title3)

              Text("Posts")
                .fontWeight(.bold)
            }
            .foregroundStyle(.orange.gradient)
            .padding(5)

            VStack {
              Text("\(data.sliceData.commentComponent, specifier: "%.1f")%")
                .fontWeight(.black)
                .font(.title3)

              Text("Comments")
                .fontWeight(.bold)
            }
            .foregroundStyle(.red.gradient)
            .padding(5)

            VStack {
              Text("\(data.sliceData.likeComponent, specifier: "%.1f")%")
                .fontWeight(.black)
                .font(.title3)

              Text("Likes")
                .fontWeight(.bold)
            }
            .foregroundStyle(.purple.gradient)
            .padding(5)
          }
          .fontDesign(.rounded)
          .padding(.horizontal)
          .opacity(showComponentBreakdown ? 1 : 0)
        }
        .frame(maxWidth: .infinity, alignment: .center)
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
      DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
        withAnimation { isShowingIntroText = false }
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
        withAnimation(.bouncy(duration: 1.7)) {
          animatedUserPercent = data.sliceData.percent
        }
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
        withAnimation(.default) {
          isShowingPercentage = true
        }
      }
    }
    .overlay(alignment: .bottom) {
      if !isShowingIntroText {
        if !isAnimatingToCenter {
          Button("Continue") {
            withAnimation(.spring) {
              isAnimatingToCenter.toggle()
            }
          }
          .buttonStyle(.borderedProminent)
        } else {
          HStack {
            Button(showComponentBreakdown ? "Hide Details" : "Show Details") {
              withAnimation(.spring) {
                showComponentBreakdown.toggle()
              }
            }
            .buttonStyle(.borderedProminent)

            Button("Continue") {
              onContinue()
            }
            .buttonStyle(.borderedProminent)
          }
        }
      }
    }
  }

  @ViewBuilder
  private var componentBreakdownText: some View {
    VStack {
      HStack {
        Circle()
          .fill(.purple.gradient)
          .frame(width: 12, height: 12)
        Text("Posts")
          .fontWeight(.semibold)
        Spacer()
        Text("\(data.sliceData.postComponent, specifier: "%.1f")%")
          .fontWeight(.black)
          .foregroundStyle(.purple.gradient)
      }

      HStack(spacing: 16) {
        Circle()
          .fill(.yellow.gradient)
          .frame(width: 12, height: 12)
        Text("Comments")
          .fontWeight(.semibold)
        Spacer()
        Text("\(data.sliceData.commentComponent, specifier: "%.1f")%")
          .fontWeight(.black)
          .foregroundStyle(.yellow.gradient)
      }

      HStack(spacing: 16) {
        Circle()
          .fill(.red.gradient)
          .frame(width: 12, height: 12)
        Text("Likes")
          .fontWeight(.semibold)
        Spacer()
        Text("\(data.sliceData.likeComponent, specifier: "%.1f")%")
          .fontWeight(.black)
          .foregroundStyle(.red.gradient)
      }
    }
    .padding(.horizontal)
    .padding(.vertical, 8)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    .padding(.horizontal)
  }

  @ViewBuilder
  private var rings: some View {
    GeometryReader { geometry in
      let size = Float(min(geometry.size.width, geometry.size.height))
      let arcMidpoint = (animatedUserPercent / 100 * 360) / 2
      let chunkRotation = isAnimatingToCenter ? -arcMidpoint : 0

      let approximateWidth = .pi * Double(size) * animatedUserPercent / 100
      let approximateHeight = size * ringWidthRatio * 0.8

      // if it's a really small percentage, we need to override the ring width when zoomed
      // in or we'll just have a tall skinny slice
      let needsHeightOverride: Bool =
        Double(approximateHeight) / approximateWidth > 2 && isAnimatingToCenter
      let ringWidth =
        needsHeightOverride ? Float(approximateWidth) : size * ringWidthRatio

      let targetScale: CGFloat = CGFloat(
        isAnimatingToCenter
          ? size
            / max(
              Float(approximateWidth),
              needsHeightOverride ? Float(approximateWidth) : approximateHeight
            ) * 0.85 : 1.0
      )

      let offsetY = isAnimatingToCenter ? size / 2 : 0

      ZStack {
        AnimatedRingSegment(
          isHighlightedSlice: false,
          startPercent: animatedUserPercent,
          endPercent: 100,
          showGap: animatedUserPercent != 0,
          ringWidth: CGFloat(ringWidth),
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
          ringWidth: CGFloat(ringWidth),
          gapDegrees: gapDegrees
        )
        .fill(.blue.gradient)
        .shadow(color: .blue.opacity(0.4), radius: 6, x: 0, y: 3)
        .rotationEffect(.degrees(chunkRotation))
        .opacity(showComponentBreakdown ? 0 : 1)
        .drawingGroup()

        if showComponentBreakdown {
          componentArcs(ringWidth: ringWidth, chunkRotation: chunkRotation)
        }

        if isShowingPercentage && !isAnimatingToCenter {
          Text("\(animatedUserPercent, specifier: "%.1f")%")
            .font(.title)
            .fontWeight(.black)
        }
      }
      .frame(width: CGFloat(size), height: CGFloat(size))
      .position(
        x: geometry.size.width / 2,
        y: geometry.size.height / 2 + CGFloat(offsetY)
      )
      .animation(.spring(duration: 0.2), value: offsetY)
      .scaleEffect(targetScale)
      .animation(.spring(duration: 1.0), value: targetScale)
      .transition(.scale.animation(.spring(duration: 5.2)))
    }
    .padding()
  }

  @ViewBuilder
  private func componentArcs(ringWidth: Float, chunkRotation: Double)
    -> some View
  {
    let postPercent = data.sliceData.postComponent
    let commentPercent = data.sliceData.commentComponent
    let likePercent = data.sliceData.likeComponent

    AnimatedRingSegment(
      isHighlightedSlice: true,
      startPercent: 0,
      endPercent: postPercent,
      showGap: false,
      ringWidth: CGFloat(ringWidth),
      gapDegrees: 0
    )
    .fill(.orange.gradient)
    .shadow(color: .orange.opacity(0.4), radius: 6, x: 0, y: 3)
    .rotationEffect(.degrees(chunkRotation))

    AnimatedRingSegment(
      isHighlightedSlice: true,
      startPercent: postPercent,
      endPercent: postPercent + commentPercent,
      showGap: false,
      ringWidth: CGFloat(ringWidth),
      gapDegrees: 0
    )
    .fill(.pink.gradient)
    .shadow(color: .pink.opacity(0.4), radius: 6, x: 0, y: 3)
    .rotationEffect(.degrees(chunkRotation))

    AnimatedRingSegment(
      isHighlightedSlice: true,
      startPercent: postPercent + commentPercent,
      endPercent: postPercent + commentPercent + likePercent,
      showGap: false,
      ringWidth: CGFloat(ringWidth),
      gapDegrees: 0
    )
    .fill(.purple.gradient)
    .shadow(color: .purple.opacity(0.4), radius: 6, x: 0, y: 3)
    .rotationEffect(.degrees(chunkRotation))
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
  UserProportionRing(data: Mocks.wrappedData, onContinue: {})
}
