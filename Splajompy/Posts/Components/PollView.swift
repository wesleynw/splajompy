import SwiftUI

struct PollView: View {
  var poll: Poll
  var authorId: Int
  var onVote: (Int) -> Void

  @Environment(AuthManager.self) private var authManager

  private var adjustedPercentages: [Int] {
    guard poll.voteTotal > 0,
      poll.currentUserVote != nil || authManager.getCurrentUser()?.userId == authorId
    else {
      return Array(repeating: 0, count: poll.options.count)
    }

    let exactPercentages = poll.options.map {
      Float($0.voteTotal * 100) / Float(poll.voteTotal)
    }
    return calculateGreatestRemainderQuotaFromList(
      percentages: exactPercentages
    )
      ?? poll.options.map { ($0.voteTotal * 100) / poll.voteTotal }
  }

  var body: some View {
    VStack(alignment: .leading) {
      if !poll.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        Text(poll.title)
          .font(.headline)
          .fontWeight(.medium)
          .multilineTextAlignment(.leading)
      }

      VStack {
        ForEach(Array(poll.options.enumerated()), id: \.offset) {
          index,
          option in
          PollOptionView(
            isSelected: index == poll.currentUserVote,
            option: option,
            showResults: poll.currentUserVote != nil
              || authManager.getCurrentUser()?.userId == authorId,
            totalVotes: poll.voteTotal,
            percentage: adjustedPercentages[index],
            onTap: { onVote(index) }
          )
        }
      }
    }
    .padding()
    .modify {
      #if os(iOS)
        $0.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
      #else
        $0.background(.quaternary, in: .rect(cornerRadius: 12))
      #endif
    }
  }

  private struct PollOptionView: View {
    let isSelected: Bool
    let option: PollOption
    let showResults: Bool
    let totalVotes: Int
    let percentage: Int
    let onTap: () -> Void

    @State private var tapped: Bool = false

    var body: some View {
      Button(action: {
        tapped.toggle()
        onTap()
      }) {
        HStack {
          Text(option.title)
            .font(.body)
            .fontWeight(.semibold)
          Spacer()
          if showResults {
            Text("\(percentage)%")
              .font(.callout)
              .foregroundColor(.secondary)
          }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background {
          GeometryReader { geometry in
            ZStack(alignment: .leading) {
              RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.2).gradient)

              RoundedRectangle(cornerRadius: 12)
                .fill(
                  isSelected
                    ? Color.blue.opacity(0.5).gradient
                    : Color.blue.opacity(0.2).gradient
                )
                .frame(width: geometry.size.width * CGFloat(percentage) / 100.0)
                .animation(
                  .spring(response: 0.4, dampingFraction: 0.75),
                  value: percentage
                )
            }
          }
        }
        .overlay {
          if isSelected {
            RoundedRectangle(cornerRadius: 12)
              .stroke(Color.blue.gradient.opacity(0.5), lineWidth: 2)
          }
        }
      }
      .buttonStyle(.plain)
      .sensoryFeedback(.impact, trigger: showResults ? false : tapped)
    }
  }
}

#Preview {
  @Previewable @State var poll: Poll = Poll(
    title: "Test Poll",
    voteTotal: 0,
    currentUserVote: nil,
    options: [
      PollOption(title: "Option A", voteTotal: 0),
      PollOption(title: "Option B", voteTotal: 0),
      PollOption(title: "Option C", voteTotal: 0),
    ]
  )

  VStack {
    PollView(
      poll: poll,
      authorId: 0,
      onVote: { option in
        poll.options[option].voteTotal += 1
        poll.voteTotal += 1
        poll.currentUserVote = option
      }
    )
    .padding()
  }
  .padding()
  .environment(AuthManager())
}
