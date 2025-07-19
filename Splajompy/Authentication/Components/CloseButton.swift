import SwiftUI

struct CloseButton: View {
  var onClose: () -> Void
  @State private var didTap = false

  var body: some View {
    Button(action: {
      didTap.toggle()
      onClose()
    }) {
      Image(systemName: "xmark")
        .font(.system(size: 15, weight: .bold))
        .fontDesign(.rounded)
        .foregroundStyle(.secondary.opacity(0.9))
        .padding(8)
        .background(.regularMaterial)
        .background(.regularMaterial, in: Circle())
    }
    .buttonStyle(.plain)
    .sensoryFeedback(.impact, trigger: didTap)
  }
}
