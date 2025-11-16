import SwiftUI

struct ActivityOverview: View {
  var data: ActivityOverviewData
  @State private var appearedIndices: Set<String> = []
  @State private var showDetail = false
  @State private var showButton = false
  @State private var showIntroText = false
  @State private var introComplete = false
  @Namespace private var animation

  private var allDates: [String] {
    data.counts.keys.sorted()
  }

  var body: some View {
    ZStack {
      if showIntroText {
        Text("You were active on Splajompy...")
          .font(.title)
          .fontWeight(.bold)
          .multilineTextAlignment(.center)
          .padding()
          .transition(.opacity)
      }
      VStack {
        ScrollView {
          LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 20), spacing: 3)],
            spacing: 3
          ) {
            ForEach(allDates, id: \.self) { day in
              let count = data.counts[day] ?? 0
              let opacity = Double(count) / Double(data.activityCountCeiling)
              RoundedRectangle(cornerRadius: 5)
                .fill(.green)
                .opacity(opacity)
                .frame(width: 20, height: 20)
                .scaleEffect(appearedIndices.contains(day) ? 1 : 0)
                .animation(
                  .spring(response: 0.25, dampingFraction: 0.6).delay(
                    allDates.firstIndex(of: day).map { Double($0) * 0.01 } ?? 0
                  ),
                  value: appearedIndices
                )
            }
          }
          .padding()

          HStack(spacing: 4) {
            Text("Less")
              .font(.caption)
              .foregroundStyle(.secondary)
            ForEach([0.2, 0.4, 0.6, 0.8, 1.0], id: \.self) { opacity in
              RoundedRectangle(cornerRadius: 2)
                .fill(.green)
                .opacity(opacity)
                .frame(width: 12, height: 12)
            }
            Text("More")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          .padding(.horizontal)

          .onChange(of: introComplete) { _, isComplete in
            if isComplete {
              for date in allDates { appearedIndices.insert(date) }
              DispatchQueue.main.asyncAfter(
                deadline: .now() + Double(allDates.count) * 0.01 + 0.5
              ) {
                withAnimation { showButton = true }
              }
            }
          }
        }
        .opacity(showDetail ? 0 : 1)
      }
      .safeAreaInset(edge: .bottom) {
        if showButton {
          Button("Continue") {}
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
            .padding()
        }
      }
    }
    .onAppear {
      withAnimation { showIntroText = true }
      DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
        withAnimation { showIntroText = false }
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
        introComplete = true
      }
    }
  }
}

#Preview {
  var counts: [String: Int] = [:]
  let df = DateFormatter()
  df.dateFormat = "yyyy-MM-dd"
  for month in 1...3 {
    for day in 1...(month == 2 ? 28 : 31) {
      if let date = Calendar.current.date(
        from: DateComponents(year: 2025, month: month, day: day)
      ) {
        counts[df.string(from: date)] = Int.random(in: 0...35)
      }
    }
  }
  return ActivityOverview(
    data: ActivityOverviewData(
      activityCountCeiling: 35,
      counts: counts,
      mostActiveDay: "2025-02-15"
    )
  )
}
