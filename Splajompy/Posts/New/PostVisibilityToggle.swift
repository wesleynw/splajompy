import SwiftUI

/// A label that displays the currently selected post visibility option and can be tapped to toggle it.
struct PostVisibilityToggle: View {
  @Binding var selectedVisibility: VisibilityType
  @State private var isPresentingUserList: Bool = false
  @Environment(AuthManager.self) var authManager

  var body: some View {
    Menu {
      Button {
        isPresentingUserList = true
      } label: {
        HStack {
          Label("Edit Friend List", systemImage: "pencil")
        }
      }

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
      menuLabel
    }
    .sheet(isPresented: $isPresentingUserList) {
      if let userId = authManager.getCurrentUser()?.userId {
        NavigationStack {
          UserListView(userId: userId, userListVariant: .friends)
            .toolbar {
              #if os(iOS)
                ToolbarItem(placement: .topBarLeading) {
                  if #available(iOS 26, *) {
                    Button(role: .close) {
                      isPresentingUserList = false
                    }
                  } else {
                    Button("Close") {
                      isPresentingUserList = false
                    }
                  }
                }
              #else
                ToolbarItem(placement: .cancellationAction) {
                  if #available(macOS 26, *) {
                    Button(role: .close) {
                      isPresentingUserList = false
                    }
                  } else {
                    Button("Close") {
                      isPresentingUserList = false
                    }
                  }
                }
              #endif
            }
            .presentationSizing(.form)
        }
      }
    }
  }

  @ViewBuilder
  private var menuLabel: some View {
    let label = HStack(spacing: 4) {
      Image(systemName: icon(for: selectedVisibility))
      Image(systemName: "chevron.down")
        .font(.caption)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 5)
    .foregroundStyle(.white)

    if #available(iOS 26, macOS 26, *) {
      label.glassEffect(
        .regular.tint(glassColor.opacity(0.7)).interactive(),
        in: .capsule
      )
    } else {
      label.background(backgroundColor, in: .capsule)
    }
  }

  private var backgroundColor: Color {
    switch selectedVisibility {
    case .everyone: return .blue
    case .friends: return .green
    }
  }

  private var glassColor: Color {
    switch selectedVisibility {
    case .everyone: return .blue
    case .friends: return .green
    }
  }

  private func title(for visibility: VisibilityType) -> String {
    switch visibility {
    case .everyone: return "Everyone"
    case .friends: return "Friends"
    }
  }

  private func icon(for visibility: VisibilityType) -> String {
    switch visibility {
    case .everyone: return "globe"
    case .friends: return "star.circle"
    }
  }
}

#Preview {
  @Previewable @State var selectedVisibility: VisibilityType = .everyone

  NavigationStack {
    PostVisibilityToggle(selectedVisibility: $selectedVisibility)
  }
  .environment(AuthManager())
}
