import SwiftUI

struct FilterCapsule: View {
  var title: String
  var isActive: Bool
  var onTap: () -> Void

  var body: some View {
    Button(action: {
      onTap()
    }) {
      Text(title)
        .fontWeight(.semibold)
        .foregroundStyle(.primary)
        .padding(10)
    }
    .buttonStyle(.plain)
    .background(
      isActive ? Color.blue.opacity(2 / 3) : Color.clear,
      in: .capsule
    )
    .background(.thinMaterial, in: .capsule)
    .overlay(
      Capsule()
        .strokeBorder(isActive ? Color.clear : Color.secondary.opacity(0.05), lineWidth: 2)
    )
  }
}

#Preview("active") {
  FilterCapsule(title: "Active Capsule", isActive: true, onTap: {})
}

#Preview("Inactive") {
  FilterCapsule(title: "Inactive Capsule", isActive: false, onTap: {})
}
