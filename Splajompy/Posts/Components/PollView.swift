import SwiftUI

struct PollView: View {
  var poll: Poll
  var onVote: (Int) -> Void

  var body: some View {
    VStack(alignment: .leading) {
      Text(poll.title)
        .font(.headline)
        .fontWeight(.medium)
        .multilineTextAlignment(.leading)

      VStack {
        ForEach(Array(poll.options.enumerated()), id: \.offset) {
          index,
          option in
          PollOptionView(
            isSelected: index == poll.currentUserVote,
            option: option,
            hasVoted: poll.currentUserVote != nil,
            totalVotes: poll.voteTotal,
            onTap: { onVote(index) }
          )
        }
      }
    }
    .padding()
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
  }

  private struct PollOptionView: View {
    let isSelected: Bool
    let option: PollOption
    let hasVoted: Bool
    let totalVotes: Int
    let onTap: () -> Void

    @State private var tapped: Bool = false

    private var percentage: Int {
      guard totalVotes > 0 else { return 0 }
      return hasVoted ? (option.voteTotal * 100) / totalVotes : 0
    }

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
          if hasVoted {
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
      .sensoryFeedback(.impact, trigger: hasVoted ? false : tapped)
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
      onVote: { option in
        poll.options[option].voteTotal += 1
        poll.voteTotal += 1
        poll.currentUserVote = option
      }
    )
    .padding()
  }
  .padding()
}
