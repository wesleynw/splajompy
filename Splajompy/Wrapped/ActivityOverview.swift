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

  private var firstDate: String? {
    allDates.first
  }

  private var lastDate: String? {
    allDates.last
  }

  private func formattedDate(_ dateString: String) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    guard let date = formatter.date(from: dateString) else { return "" }
    formatter.dateFormat = "MMM d"
    return formatter.string(from: date)
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
          VStack(spacing: 12) {
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
                      allDates.firstIndex(of: day).map { Double($0) * 0.01 }
                        ?? 0
                    ),
                    value: appearedIndices
                  )
              }
            }
            .overlay(alignment: .topLeading) {
              if let first = firstDate {
                VStack(alignment: .leading, spacing: 4) {
                  Image(systemName: "arrow.down.left")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                  Text(formattedDate(first))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                .offset(x: -8, y: -32)
              }
            }
            .overlay(alignment: .bottomTrailing) {
              if let last = lastDate {
                VStack(alignment: .trailing, spacing: 4) {
                  Text(formattedDate(last))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                  Image(systemName: "arrow.up.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                .offset(x: 8, y: 32)
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
          }
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
            NavigationLink(destination: UserProportionRing(userPercent: 4)) {
              Text("Continue")
                .padding(3)
                .fontWeight(.black)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
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
  for month in 1...12 {
    for day in 1...([4, 6, 9, 11].contains(month) ? 30 : month == 2 ? 28 : 31) {
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
