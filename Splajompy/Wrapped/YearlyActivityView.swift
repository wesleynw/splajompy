import SwiftUI

struct YearlyActivityView: View {
  var data: WrappedData
  var onContinue: () -> Void

  @State private var appearedIndices: Set<String> = []
  @State private var showContinueButton: Bool = false
  @State private var showIntroText: Bool = true
  @Namespace private var animation

  private var allDates: [String] {
    data.activityData.counts.keys.sorted()
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
    if showIntroText {
      VStack {
        Text("But what about over the course of the entire year?")
          .font(.title2)
          .fontWeight(.bold)
          .multilineTextAlignment(.center)
          .fontDesign(.rounded)
          .transition(.opacity)

        HStack(spacing: 4) {
          Text("Less")
            .font(.caption)
            .foregroundStyle(.secondary)
          ForEach([0.2, 0.4, 0.6, 0.8, 1.0], id: \.self) {
            opacity in
            RoundedRectangle(cornerRadius: 2)
              .fill(.green)
              .opacity(opacity)
              .frame(width: 12, height: 12)
          }
          Text("More")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
      }
      .padding()
      .onAppear {
        withAnimation { showIntroText = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
          withAnimation { showIntroText = false }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
          for date in allDates {
            appearedIndices.insert(date)
          }
          DispatchQueue.main.asyncAfter(
            deadline: .now() + Double(allDates.count) * 0.01
              + 0.5
          ) {
            withAnimation { showContinueButton = true }
          }
        }
      }
    } else {
      VStack {
        ScrollView {
          VStack(spacing: 12) {
            LazyVGrid(
              columns: [
                GridItem(.adaptive(minimum: 20), spacing: 3)
              ],
              spacing: 3
            ) {
              ForEach(allDates, id: \.self) { day in
                let count = data.activityData.counts[day] ?? 0
                let opacity =
                  Double(count)
                  / Double(
                    data.activityData.activityCountCeiling
                  )
                RoundedRectangle(cornerRadius: 5)
                  .fill(.green)
                  .opacity(opacity)
                  .frame(width: 20, height: 20)
                  .overlay(
                    RoundedRectangle(cornerRadius: 5)
                      .stroke(.gray.opacity(0.2), lineWidth: 1)
                  )
                  .scaleEffect(
                    appearedIndices.contains(day) ? 1 : 0
                  )
                  .animation(
                    .spring(
                      response: 0.25,
                      dampingFraction: 0.6
                    ).delay(
                      allDates.firstIndex(of: day).map {
                        Double($0) * 0.01
                      }
                        ?? 0
                    ),
                    value: appearedIndices
                  )
              }
            }
            .padding()

          }
        }
      }
      .overlay(alignment: .bottom) {
        if showContinueButton {
          Button("Continue") {
            onContinue()
          }
          .frame(maxWidth: .infinity)
          .buttonStyle(.borderedProminent)
        }
      }
    }

  }
}

#Preview {
  YearlyActivityView(data: Mocks.wrappedData, onContinue: {})
}
