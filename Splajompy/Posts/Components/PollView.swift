import SwiftUI

struct PollView: View {
  let poll: Poll
  @State private var selectedOptionId: String? = nil
  @State private var hasVoted = false
  @State private var animatedPercentages: [String: Double] = [:]

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(poll.question)
        .font(.headline)
        .fontWeight(.medium)
        .multilineTextAlignment(.leading)

      VStack(spacing: 8) {
        ForEach(poll.options) { option in
          PollOptionView(
            option: option,
            totalVotes: poll.totalVotes,
            isSelected: selectedOptionId == option.id,
            hasVoted: hasVoted,
            animatedPercentage: animatedPercentages[option.id] ?? 0.0
          ) {
            optionTapped(option)
          }
        }
      }

    }
    .padding()
    .background(.regularMaterial)
    .cornerRadius(12)
    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
  }

  private func optionTapped(_ option: PollOption) {
    guard !hasVoted else { return }

    print("Poll option tapped: \(option.text)")

    selectedOptionId = option.id
    hasVoted = true

    withAnimation(.easeInOut(duration: 0.3)) {
      for pollOption in poll.options {
        animatedPercentages[pollOption.id] = pollOption.percentage(
          of: poll.totalVotes
        )
      }
    }
  }
}

struct PollOptionView: View {
  let option: PollOption
  let totalVotes: Int
  let isSelected: Bool
  let hasVoted: Bool
  let animatedPercentage: Double
  let onTap: () -> Void

  private var percentage: Double {
    option.percentage(of: totalVotes)
  }

  var body: some View {
    Button(action: onTap) {
      HStack {
        Text(option.text)
          .font(.body)
          .foregroundColor(.primary)
          .multilineTextAlignment(.leading)

        Spacer()

        if hasVoted {
          HStack(spacing: 6) {
            if isSelected {
              Image(systemName: "checkmark")
                .foregroundColor(.blue)
                .font(.caption)
                .fontWeight(.bold)
            }
            Text("\(String(format: "%.1f", animatedPercentage))%")
              .font(.caption)
              .fontWeight(.medium)
              .foregroundColor(isSelected ? .blue : .secondary)
          }
        } else if isSelected {
          Image(systemName: "checkmark")
            .foregroundColor(.blue)
            .font(.body)
            .fontWeight(.bold)
        }
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
      .background(
        ZStack(alignment: .leading) {
          RoundedRectangle(cornerRadius: 8)
            .fill(
              isSelected && !hasVoted
                ? Color.blue.opacity(0.6) : Color.secondary.opacity(0.1)
            )

          if hasVoted {
            RoundedRectangle(cornerRadius: 8)
              .fill(
                isSelected ? Color.blue.opacity(0.5) : Color.blue.opacity(0.2)
              )
              .frame(width: calculateBarWidth())
          }
        }
      )
    }
    .buttonStyle(PlainButtonStyle())
  }

  private func calculateBarWidth() -> CGFloat {
    let screenWidth = UIScreen.main.bounds.width
    let maxWidth = screenWidth - 64
    return maxWidth * (animatedPercentage / 100.0)
  }
}

#Preview {
  Spacer()
  VStack(spacing: 20) {
    PollView(
      poll: Poll(
        question: "What's your favorite programming language?",
        options: [
          PollOption(text: "Swift", voteCount: 45),
          PollOption(text: "Python", voteCount: 32),
          PollOption(text: "JavaScript", voteCount: 28),
          PollOption(text: "Rust", voteCount: 15),
        ],
        totalVotes: 120
      )
    )
    .padding()
  }
  Spacer()
}
