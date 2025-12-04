import SwiftUI

let days = ["Sun", "Mo", "Tu", "We", "Th", "Fr", "Sat"]

struct WeeklyActivityView: View {
  var data: WrappedData
  var onContinue: () -> Void
  @State private var animatedHeights: [CGFloat] = Array(repeating: 0, count: 7)
  @State private var isShowingIntroText: Bool = true
  @State private var isShowingContinueButton: Bool = false

  var body: some View {
    GeometryReader { proxy in
      HStack {
        ForEach(Array(days.enumerated()), id: \.offset) { index, elem in
          VStack {
            ZStack(alignment: .bottom) {
              RoundedRectangle(cornerRadius: 20)
                .frame(height: proxy.size.height / 2.5)
                .foregroundStyle(.thickMaterial)
                .overlay {
                  RoundedRectangle(cornerRadius: 20)
                    .stroke(.gray.tertiary)
                }

              RoundedRectangle(cornerRadius: 20)
                .frame(
                  height: proxy.size.height / 2.5
                    * animatedHeights[index] / 100
                )
                .foregroundStyle(.green.gradient)
            }
            Text(elem)
              .fontWeight(.black)
              .fontDesign(.rounded)
          }
          .frame(maxWidth: .infinity)
        }
      }
      .padding()
      .frame(width: proxy.size.width, height: proxy.size.height)
      .onAppear {
        for index in 0..<7 {
          withAnimation(.bouncy.delay(Double(index) * 0.4)) {
            animatedHeights[index] = CGFloat(data.weeklyActivityData[index])
          }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
          withAnimation {
            isShowingContinueButton = true
          }
        }
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
  }
}

#Preview {
  WeeklyActivityView(data: Mocks.wrappedData, onContinue: {})
}
