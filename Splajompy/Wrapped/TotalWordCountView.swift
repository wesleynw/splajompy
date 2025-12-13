import SwiftUI

struct TotalWordCountView: View {
  var data: WrappedData
  var onContinue: () -> Void

  @State private var isShowingContinueButton: Bool = false
  @State private var isShowingIntroText: Bool = true
  @State private var animationProgress: CGFloat = 0

  var body: some View {
    VStack {
      if isShowingIntroText {
        Text("You had a lot to say this year...")
          .foregroundStyle(.black)
          .font(.title2)
          .transition(.scale)
          .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
              withAnimation {
                isShowingIntroText = false
              }
              withAnimation(.spring) {
                animationProgress = 1
              }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
              withAnimation {
                isShowingContinueButton = true
              }
            }
          }
      } else {
        ZStack {
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

          HStack {
            Text("You wrote ")
              + Text(data.totalWordCount.formatted()).foregroundStyle(
                .indigo.gradient
              )
              + Text(" words on Splajompy")
          }
          .padding()
          .foregroundStyle(.black)
          .multilineTextAlignment(.center)
          .fontWeight(.bold)
          .font(.title2)
          .opacity(animationProgress)
        }
        .transition(.scale)
      }
    }
    .safeAreaInset(edge: .bottom) {
      if isShowingContinueButton {
        Button("Continue") {
          onContinue()
        }
        .buttonStyle(.borderedProminent)
      }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.cyan.gradient)
    .preferredColorScheme(.light)
    .fontDesign(.rounded)
    .fontWeight(.bold)
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
  TotalWordCountView(data: Mocks.wrappedData, onContinue: {})
}
