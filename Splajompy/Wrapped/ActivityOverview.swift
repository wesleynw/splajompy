import SwiftUI

struct ActivityOverview: View {
  var data: ActivityOverviewData
  @State private var appearedIndices: Set<String> = []
  @State private var showDetail = false
  @State private var showButton = false
  @State private var showIntroText = false
  @State private var introComplete = false
  @Namespace private var animation

  private var calendarMonths: [[[String?]]] {
    let df = DateFormatter()
    df.dateFormat = "yyyy-MM-dd"
    let cal = Calendar.current

    var months: [Date: [String]] = [:]
    for dateString in data.counts.keys {
      guard let date = df.date(from: dateString),
        let month = cal.date(from: cal.dateComponents([.year, .month], from: date))
      else { continue }
      months[month, default: []].append(dateString)
    }

    return months.sorted(by: { $0.key < $1.key }).map { month, _ in
      let firstWeekday = cal.component(.weekday, from: month)
      let days = cal.range(of: .day, in: .month, for: month)!.count
      var grid: [[String?]] = []
      var week: [String?] = Array(repeating: nil, count: firstWeekday - 1)

      for day in 1...days {
        week.append(df.string(from: cal.date(byAdding: .day, value: day - 1, to: month)!))
        if week.count == 7 {
          grid.append(week)
          week = []
        }
      }
      if !week.isEmpty {
        week += Array(repeating: nil, count: 7 - week.count)
        grid.append(week)
      }
      return grid
    }
  }

  private var allDates: [String] {
    calendarMonths.flatMap { $0.flatMap { $0.compactMap { $0 } } }
  }

  private func monthLabel(for month: [[String?]]) -> String {
    guard let firstDate = month.flatMap({ $0 }).compactMap({ $0 }).first else { return "" }
    let df = DateFormatter()
    df.dateFormat = "yyyy-MM-dd"
    guard let date = df.date(from: firstDate) else { return "" }
    df.dateFormat = "MMM"
    return df.string(from: date)
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
          LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
            ForEach(Array(calendarMonths.enumerated()), id: \.offset) { _, month in
              VStack(spacing: 4) {
                Text(monthLabel(for: month))
                  .font(.caption2)
                  .foregroundStyle(.secondary.opacity(0.5))

                VStack(spacing: 2) {
                  ForEach(Array(month.enumerated()), id: \.offset) { _, week in
                    HStack(spacing: 2) {
                      ForEach(Array(week.enumerated()), id: \.offset) { _, dateString in
                        let count = dateString.flatMap { data.counts[$0] } ?? 0
                        let opacity =
                          dateString == nil
                          ? 0
                          : (count == 0 ? 0.05 : Double(count) / Double(data.activityCountCeiling))
                        RoundedRectangle(cornerRadius: 2)
                          .fill(.green)
                          .opacity(opacity)
                          .frame(width: 12, height: 12)
                          .scaleEffect(
                            dateString.map { appearedIndices.contains($0) } ?? false ? 1 : 0
                          )
                          .animation(
                            .spring(response: 0.25, dampingFraction: 0.6).delay(
                              dateString.flatMap { allDates.firstIndex(of: $0) }.map {
                                Double($0) * 0.01
                              } ?? 0
                            ),
                            value: appearedIndices
                          )
                      }
                    }
                  }
                }
              }
            }
          }
          .padding()
          .onChange(of: introComplete) { _, isComplete in
            if isComplete {
              for date in allDates { appearedIndices.insert(date) }
              DispatchQueue.main.asyncAfter(deadline: .now() + Double(allDates.count) * 0.01 + 0.5)
              {
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
      if let date = Calendar.current.date(from: DateComponents(year: 2025, month: month, day: day))
      {
        counts[df.string(from: date)] = Int.random(in: 0...35)
      }
    }
  }

  return ActivityOverview(
    data: ActivityOverviewData(
      activityCountCeiling: 35,
      counts: counts,
      mostActiveDay: "2025-02-15"
    ))
}
