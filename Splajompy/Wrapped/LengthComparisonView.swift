import SwiftUI

struct LengthComparisonView: View {
  var data: WrappedData
  var onContinue: () -> Void
  @State private var isShowingSubheadline1: Bool = false
  @State private var isShowingSubheadline2: Bool = false
  @State private var isShowingContinueButton: Bool = false

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
    VStack(alignment: .center) {
      Text(getHeadline())
        .font(.largeTitle)
        .onAppear {
          DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation {
              isShowingSubheadline1 = true
            }
          }

          DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            withAnimation {
              isShowingSubheadline2 = true
            }
          }
        }
        .padding()

      if isShowingSubheadline1 {
        HStack {
          Text("Your posts are ")
            + Text(
              "\(abs(data.comparativePostStatisticsData.postLengthVariation), specifier: "%.1f")% "
            )
            .foregroundStyle(.blue)
            + Text("\(getLongerShorterPosts()) than average.")
        }
        .font(.title)
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
        .font(.title)
        .onAppear {
          DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            withAnimation {
              isShowingContinueButton = true
            }
          }
        }
      }
    }
    .frame(maxHeight: .infinity)
    .overlay(alignment: .bottom) {
      if isShowingContinueButton {
        Button("Continue") {
          onContinue()
        }
        .buttonStyle(.borderedProminent)
      }
    }
    .padding()
    .fontWeight(.bold)
    .fontDesign(.rounded)
    .multilineTextAlignment(.center)
  }
}

#Preview {
  LengthComparisonView(data: Mocks.wrappedData, onContinue: {})
}
