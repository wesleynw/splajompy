import SwiftUI

struct PollView: View {
  @Binding var poll: Poll

  var body: some View {
    VStack(alignment: .leading) {
      Text(poll.title)
        .font(.headline)
        .fontWeight(.medium)
        .multilineTextAlignment(.leading)

      VStack {
        ForEach(poll.options) { option in
          PollOptionView(
            isSelected: option.id == poll.selectedOptionId,
            option: option,
            hasVoted: poll.hasVoted,
            totalVotes: poll.voteTotal,
            onTap: { onOptionSelected(option) }
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

    private var percentage: Int {
      guard totalVotes > 0 else { return 0 }
      return hasVoted ? (option.voteTotal * 100) / totalVotes : 0
    }

    var body: some View {
      Button(action: onTap) {
        HStack {
          Text(option.label)
            .font(.body)
            .fontWeight(.semibold)
          Spacer()
          if hasVoted {
            Text("\(percentage)%")
              .font(.callout)
//              .font(.footnote)
              .foregroundColor(.secondary)
          }
        }
        .padding(12)
        .background {
          ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 12)
              .fill(Color.secondary.opacity(0.2).gradient)

            RoundedRectangle(cornerRadius: 12)
              .fill(isSelected ? Color.blue.opacity(0.5).gradient : Color.blue.opacity(0.2).gradient)
              .containerRelativeFrame(
                .horizontal,
                count: 100,
                span: percentage,
                spacing: 0
              )
              .scaleEffect(x: hasVoted ? 1.0 : 0.0, anchor: .leading)
              .animation(
                .spring(response: 0.4, dampingFraction: 0.75),
                value: hasVoted
              )
          }
        }
      }
      .buttonStyle(.plain)
    }
  }

  private func onOptionSelected(_ option: PollOption) {
    guard !poll.hasVoted else { return }

    print("selected option in poll: \(option.label)")
    poll.selectedOptionId = option.id
  }
}

#Preview {
  @Previewable @State var poll: Poll = Poll(
    title: "Test Poll",
    voteTotal: 10,
    options: [
      PollOption(id: 0, label: "Option A", voteTotal: 3),
      PollOption(id: 1, label: "Option B", voteTotal: 2),
      PollOption(id: 2, label: "Option C", voteTotal: 5),
    ],
    selectedOptionId: nil
  )
  PollView(poll: $poll)
}
