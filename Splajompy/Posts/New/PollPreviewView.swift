import SwiftUI

struct PollPreviewView: View {
  let poll: PollCreationRequest
  let onRemove: () -> Void
  let onEdit: () -> Void

  var body: some View {
    Button(action: onEdit) {
      HStack {
        Image(systemName: "chart.bar.fill")
          .foregroundStyle(.accent)
          .font(.body)

        if !poll.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          Text(poll.title)
            .font(.body)
            .fontWeight(.semibold)
            .lineLimit(1)
            .truncationMode(.tail)
        } else {
          Text("Poll")
            .font(.body)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
        }

        Spacer()
      }
      .padding()
    }
    .buttonStyle(.plain)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    .overlay(alignment: .topTrailing) {
      Button {
        onRemove()
      } label: {
        ZStack {
          Circle()
            .fill(.regularMaterial)
            .frame(width: 22, height: 22)
            .shadow(
              color: Color.black.opacity(0.2),
              radius: 2,
              x: 0,
              y: 1
            )

          Image(systemName: "xmark")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.gray)
        }
      }
      .buttonStyle(.plain)
      .offset(x: 8, y: -8)
    }
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
