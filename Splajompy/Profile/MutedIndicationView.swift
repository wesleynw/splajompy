import SwiftUI

struct MutedIndicationView: View {
  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: "speaker.slash.fill")
      Text("This person is muted")
        .font(.subheadline)
    }
    .foregroundStyle(.secondary)
    .frame(maxWidth: .infinity)
    .padding()
    .background(.ultraThinMaterial)
    .cornerRadius(20)
  }
}

#Preview {
  MutedIndicationView()
    .padding()
}
