import SwiftUI

/// A label that displays the currently selected post visibility option and can be tapped to toggle it.
struct PostVisibilityToggle: View {
  @Binding var selectedVisibility: VisibilityType

  var body: some View {
    Menu {
      ForEach(VisibilityType.allCases) { visibility in
        Button {
          selectedVisibility = visibility
        } label: {
          HStack {
            Label(title(for: visibility), systemImage: icon(for: visibility))
            if selectedVisibility == visibility {
              Image(systemName: "checkmark")
            }
          }
        }
      }
    } label: {
      HStack(spacing: 4) {
        Image(systemName: icon(for: selectedVisibility))
        Text(title(for: selectedVisibility))
        Image(systemName: "chevron.down")
          .font(.caption)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .foregroundStyle(.white)
      .modify {
        if #available(iOS 26, macOS 26, *) {
          $0.glassEffect(.regular.tint(glassColor.opacity(0.7)).interactive(), in: .capsule)
        } else {
          $0.background(backgroundColor, in: Capsule())
        }
      }
    }
  }

  private var backgroundColor: Color {
    switch selectedVisibility {
    case .Public: return .blue
    case .CloseFriends: return .green
    }
  }

  private var glassColor: Color {
    switch selectedVisibility {
    case .Public: return .blue
    case .CloseFriends: return .green
    }
  }

  private func title(for visibility: VisibilityType) -> String {
    switch visibility {
    case .Public: return "Anyone"
    case .CloseFriends: return "Close Friends"
    }
  }

  private func icon(for visibility: VisibilityType) -> String {
    switch visibility {
    case .Public: return "globe"
    case .CloseFriends: return "star.circle"
    }
  }
}

#Preview {
  @Previewable @State var selectedVisibility: VisibilityType = .Public
  PostVisibilityToggle(selectedVisibility: $selectedVisibility)
}
