import SwiftUI

struct LengthComparisonView: View {
  var data: WrappedData
  var onContinue: () -> Void
  @State private var isShowingIntroText: Bool = true
  @State private var isShowingSubheadline1: Bool = false
  @State private var isShowingSubheadline2: Bool = false
  @State private var isShowingContinueButton: Bool = false
  @State private var animationProgress: CGFloat = 0

  func getHeadline() -> String {
    let reference = data.comparativePostStatisticsData.postLengthVariation

    if reference > 3 {
      return "You talk a lot!"
    } else if reference < -3 {
      return "You're pretty quiet!"
    } else {
      return "You're pretty normal!"
    }
  }

  func getLongerShorterPosts() -> String {
    return data.comparativePostStatisticsData.postLengthVariation > 0
      ? "longer" : "shorter"
  }

  func getMoreLessImages() -> String {
    return data.comparativePostStatisticsData.imageLengthVariation > 0
      ? "more" : "fewer"
  }

  var body: some View {
    ZStack {
      if !isShowingIntroText {
        ConcentricStroke(progress: animationProgress, scale: 1, delay: 0)
        ConcentricStroke(
          progress: animationProgress,
          scale: 0.618,
          delay: 0.1
        )
        ConcentricStroke(
          progress: animationProgress,
          scale: 0.381924,
          delay: 0.2
        )
        ConcentricStroke(
          progress: animationProgress,
          scale: 0.243667512,
          delay: 0.3
        )
        ConcentricStroke(
          progress: animationProgress,
          scale: 0.1505865224,
          delay: 0.4
        )
        ConcentricStroke(
          progress: animationProgress,
          scale: 0.09306247084,
          delay: 0.5
        )
        ConcentricStroke(
          progress: animationProgress,
          scale: 0.05751260698,
          delay: 0.6
        )
      }

      VStack(alignment: .center) {
        if isShowingIntroText {
          Text(getHeadline())
            .font(.title2)
            .onAppear {
              DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation {
                  isShowingIntroText = false
                }

                withAnimation(.spring) {
                  animationProgress = 1
                }
              }

              DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                  isShowingSubheadline1 = true
                }
              }

              DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
                withAnimation {
                  isShowingSubheadline2 = true
                }
              }
            }
            .padding()
        }

        if isShowingSubheadline1 {
          HStack {
            Text("Your posts are ")
              + Text(
                "\(abs(data.comparativePostStatisticsData.postLengthVariation), specifier: "%.1f")% "
              )
              .foregroundStyle(.blue)
              + Text("\(getLongerShorterPosts()) than average.")
          }
          .font(.title2)
          .padding()
        }

        if isShowingSubheadline2 {
          HStack {
            Text("And usually contain ")
              + Text(
                "\(abs(data.comparativePostStatisticsData.imageLengthVariation), specifier: "%.1f")% "
              )
              .foregroundStyle(.red)
              + Text("\(getMoreLessImages()) images than average.")
          }
          .font(.title2)
          .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
              withAnimation {
                isShowingContinueButton = true
              }
            }
          }
        }
      }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.green.gradient.secondary)
    .fontWeight(.bold)
    .fontDesign(.rounded)
    .overlay(alignment: .bottom) {
      if isShowingContinueButton {
        Button("Continue") {
          onContinue()
        }
        .fontWeight(.bold)
        .modify {
          if #available(iOS 26, macOS 26, *) {
            $0.buttonStyle(.glassProminent)
          } else {
            $0.buttonStyle(.borderedProminent)
          }
        }
      }
    }
    .multilineTextAlignment(.center)
  }
}

struct ConcentricStroke: View {
  let progress: CGFloat
  let scale: CGFloat
  let delay: CGFloat

  private var adjustedProgress: CGFloat {
    max(0, (progress - delay) * (1 / (1 - delay)))
  }

  var body: some View {
    RoundedRectangle(cornerRadius: 30)
      .stroke(.indigo.opacity(0.33), lineWidth: 3)
      .scaleEffect(scale * adjustedProgress)
      .opacity(adjustedProgress)
  }
}

#Preview {
  LengthComparisonView(data: Mocks.wrappedData, onContinue: {})
}
