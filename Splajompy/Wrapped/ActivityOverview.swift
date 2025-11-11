import SwiftUI

struct ActivityOverviewData {
  let activityCountCeiling: Int
  let counts: [Int]
}

struct ActivityOverview: View {
  var data: ActivityOverviewData
  @State private var appearedIndices: Set<Int> = []
  @State private var showDetail = false
  @State private var cornerRadius: CGFloat = 5
  @Namespace private var animation

  private var ceilingDayIndex: Int? {
    data.counts.firstIndex(of: data.activityCountCeiling)
  }

  var body: some View {
    ZStack {
      VStack {
        ScrollView {
          LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 20), spacing: 5)],
            spacing: 5
          ) {
            ForEach(data.counts.indices, id: \.self) { index in
              RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.green)
                .matchedGeometryEffect(
                  id: index == ceilingDayIndex ? "ceilingDay" : "day\(index)",
                  in: animation,
                )
                .frame(width: 20, height: 20)
                .opacity(
                  Double(data.counts[index]) / Double(data.activityCountCeiling)
                )
                .overlay {
                  RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.secondary.opacity(0.3), lineWidth: 1)
                }
                .scaleEffect(appearedIndices.contains(index) ? 1 : 0)
                .animation(
                  .spring(response: 0.25, dampingFraction: 0.6).delay(
                    Double(index) * 0.02
                  ),
                  value: appearedIndices
                )
            }
          }
          .padding()
          .onAppear {
            for index in data.counts.indices {
              appearedIndices.insert(index)
            }
          }
        }
        .opacity(showDetail ? 0 : 1)
        .overlay {
          if showDetail {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
              .fill(.green)
              .matchedGeometryEffect(
                id: "ceilingDay",
                in: animation,
                isSource: true
              )
              .frame(width: 200, height: 200)
          }
        }

        Button {
          withAnimation(.spring) {
            showDetail.toggle()
            cornerRadius = showDetail ? 50 : 5
          }
        } label: {
          Text("Continue")
            .fontWeight(.bold)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .padding()
      }
    }
  }
}

#Preview {
  let sampleData = ActivityOverviewData(
    activityCountCeiling: 35,
    counts: [
      5,
      0,
      2,
      1,
      3,
      5,
      1,
      12,
      6,
      2,
      1,
      0,
      4,
      6,
      3,
      7,
      7,
      6,
      7,
      3,
      3,
      8,
      1,
      2,
      11,
      6,
      5,
      12,
      3,
      11,
      11,
      4,
      3,
      1,
      6,
      6,
      1,
      3,
      4,
      5,
      3,
      2,
      0,
      3,
      2,
      0,
      3,
      5,
      2,
      4,
      0,
      2,
      0,
      0,
      9,
      5,
      8,
      6,
      6,
      0,
      3,
      3,
      8,
      9,
      6,
      6,
      19,
      11,
      16,
      15,
      16,
      3,
      24,
      22,
      3,
      18,
      7,
      22,
      4,
      15,
      8,
      11,
      3,
      6,
      7,
      7,
      6,
      8,
      4,
      5,
      9,
      6,
      6,
      7,
      6,
      4,
      0,
      4,
      3,
      7,
      3,
      4,
      6,
      3,
      3,
      11,
      10,
      5,
      6,
      2,
      5,
      1,
      1,
      1,
      5,
      9,
      5,
      7,
      11,
      6,
      6,
      1,
      3,
      3,
      2,
      11,
      4,
      8,
      17,
      3,
      12,
      4,
      3,
      5,
      10,
      12,
      2,
      11,
      17,
      12,
      12,
      10,
      6,
      13,
      11,
      7,
      3,
      4,
      4,
      9,
      18,
      8,
      7,
      9,
      8,
      10,
      8,
      17,
      8,
      4,
      34,
      21,
      7,
      10,
      9,
      10,
      6,
      11,
      11,
      4,
      15,
      10,
      4,
      9,
      14,
      7,
      6,
      15,
      7,
      4,
      4,
      4,
      15,
      15,
      3,
      8,
      2,
      8,
      5,
      9,
      1,
      13,
      6,
      3,
      13,
      3,
      18,
      11,
      8,
      5,
      11,
      12,
      5,
      19,
      17,
      8,
      20,
      18,
      7,
      5,
      3,
      5,
      8,
      11,
      8,
      1,
      18,
      19,
      12,
      27,
      28,
      6,
      19,
      15,
      16,
      9,
      14,
      9,
      17,
      12,
      5,
      11,
      21,
      9,
      17,
      4,
      17,
      9,
      27,
      28,
      26,
      10,
      14,
      13,
      7,
      35,
      21,
      9,
      17,
      14,
      9,
      4,
      13,
      12,
      22,
      24,
      10,
      9,
      7,
      14,
      33,
      13,
      26,
      6,
      9,
      17,
      17,
      9,
      12,
      13,
      18,
      17,
      15,
      5,
      21,
      15,
      27,
      20,
      12,
      14,
      29,
      11,
      16,
      31,
      27,
      28,
      14,
      20,
      24,
      20,
      8,
      30,
      32,
      10,
      20,
      22,
      20,
      8,
      27,
      17,
      19,
      27,
      9,
      25,
      28,
      18,
      18,
      6,
      26,
      18,
      34,
      10,
      6,
      22,
      2,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
    ]
  )

  NavigationStack {
    ActivityOverview(data: sampleData)
  }
}
