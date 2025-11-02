import SwiftUI

struct PollPreviewView: View {
  let poll: PollCreationRequest
  let onRemove: () -> Void
  let onEdit: () -> Void

  var body: some View {
    Group {
      HStack {
        Image(systemName: "chart.bar.fill")
          .foregroundColor(.blue)
          .font(.body)

        VStack(alignment: .leading, spacing: 2) {
          if !poll.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text(poll.title)
              .font(.body)
              .fontWeight(.semibold)
              .multilineTextAlignment(.leading)
          } else {
            Text("Poll")
              .font(.body)
              .fontWeight(.semibold)
              .foregroundColor(.secondary)
          }

          Text("\(poll.options.count) options")
            .font(.caption)
            .foregroundColor(.secondary)
        }

        Spacer()

        Button("Edit") {
          onEdit()
        }
        .font(.callout)
        .fontWeight(.medium)
        .foregroundColor(.blue)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
          Color.blue.opacity(0.1),
          in: RoundedRectangle(cornerRadius: 6)
        )

        Button {
          onRemove()
        } label: {
          Image(systemName: "xmark.circle.fill")
            .foregroundColor(.red)
            .font(.title3)
        }
        .padding(.leading, 4)
      }
      .padding()
    }
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    .padding()
  }
}

#Preview {
  PollPreviewView(
    poll: PollCreationRequest(
      title: "What's your favorite programming language?",
      options: ["Swift", "Python", "JavaScript", "Rust"]
    ),
    onRemove: {},
    onEdit: {}
  )
}
