import SwiftUI

struct LengthComparisonView: View {
  var data: WrappedData
  @State private var isShowingSubheadline1: Bool = false
  @State private var isShowingSubheadline2: Bool = false

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
            + Text("\(getLongerShorterPosts()) than the average post.")
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
            + Text("\(getMoreLessImages()) images than the average post.")
        }
        .font(.title)
      }
    }
    .padding()
    .fontWeight(.bold)
    .fontDesign(.rounded)
    .multilineTextAlignment(.center)
  }
}

#Preview {
  LengthComparisonView(data: Mocks.wrappedData)
}
