import SwiftUI

let days = ["Sun", "Mo", "Tu", "We", "Th", "Fr", "Sat"]

struct WeeklyActivityView: View {
  var data: WrappedData
  var onContinue: () -> Void
  @State private var animatedHeights: [CGFloat] = Array(repeating: 0, count: 7)
  @State private var isShowingIntroText: Bool = true
  @State private var isShowingContinueButton: Bool = false

  var body: some View {
    ZStack {
      CircuitBoardBackground()

      if isShowingIntroText {
        Text("What does a week on Splajompy look like for you?")
          .fontDesign(.rounded)
          .font(.title2)
          .fontWeight(.bold)
          .multilineTextAlignment(.center)
          .padding()
          .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
              withAnimation {
                isShowingIntroText = false
              }
            }
          }
      } else {
        GeometryReader { proxy in
          VStack {
            Text("Your week in Splajompy")
              .fontDesign(.rounded)
              .font(.title2)
              .fontWeight(.black)
              .padding(.bottom, 20)

            HStack {
              ForEach(Array(days.enumerated()), id: \.offset) { index, elem in
                VStack {
                  ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 20)
                      .frame(height: proxy.size.height / 2.5)
                      .foregroundStyle(.thinMaterial)
                      .overlay {
                        RoundedRectangle(cornerRadius: 20)
                          .stroke(.gray.secondary)
                      }

                    RoundedRectangle(cornerRadius: 20)
                      .frame(
                        height: proxy.size.height / 2.5
                          * animatedHeights[index] / 100
                      )
                      .foregroundStyle(.green.gradient)
                      .shadow(
                        color: .green,
                        radius: 1
                      )
                      .compositingGroup()
                  }
                  Text(elem)
                    .fontWeight(.black)
                    .fontDesign(.rounded)
                }
                .frame(maxWidth: .infinity)
              }
            }
            .padding()
            .onAppear {
              for index in 0..<7 {
                withAnimation(.bouncy.delay(Double(index) * 0.4)) {
                  animatedHeights[index] = CGFloat(
                    data.weeklyActivityData[index]
                  )
                }
              }

              DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                withAnimation {
                  isShowingContinueButton = true
                }
              }
            }
          }
          .frame(maxHeight: .infinity, alignment: .center)

        }
        .overlay(alignment: .bottom) {
          if isShowingContinueButton {
            Button("Continue") {
              onContinue()
            }
            .buttonStyle(.borderedProminent)
          }
        }
      }
    }
    .background(.blue.gradient.secondary)
  }
}

struct CircuitBoardBackground: View {
  var body: some View {
    Canvas { context, size in
      let gridSize: CGFloat = 50

      for row in 0..<Int(size.height / gridSize) {
        for col in 0..<Int(size.width / gridSize) {
          let x = CGFloat(col) * gridSize
          let y = CGFloat(row) * gridSize

          if Bool.random() {
            var path = Path()
            path.move(to: CGPoint(x: x + gridSize / 2, y: y))
            path.addLine(to: CGPoint(x: x + gridSize / 2, y: y + gridSize))
            context.stroke(
              path,
              with: .color(.primary.opacity(0.08)),
              lineWidth: 1
            )
          }

          if Bool.random() {
            var path = Path()
            path.move(to: CGPoint(x: x, y: y + gridSize / 2))
            path.addLine(to: CGPoint(x: x + gridSize, y: y + gridSize / 2))
            context.stroke(
              path,
              with: .color(.primary.opacity(0.08)),
              lineWidth: 1
            )
          }

          context.fill(
            Path(
              ellipseIn: CGRect(
                x: x + gridSize / 2 - 2,
                y: y + gridSize / 2 - 2,
                width: 4,
                height: 4
              )
            ),
            with: .color(.primary.opacity(0.1))
          )
        }
      }
    }
    .ignoresSafeArea()
  }
}

#Preview {
  WeeklyActivityView(data: Mocks.wrappedData, onContinue: {})
}
