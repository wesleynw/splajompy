import SwiftUI

struct AppIconPickerView: View {
  @State private var selectedIcon: String?

  init() {
    _selectedIcon = State(initialValue: UIApplication.shared.alternateIconName)
  }

  var body: some View {
    HStack(spacing: 20) {
      Image("icon-png")
        .resizable()
        .frame(width: 80, height: 80)
        .cornerRadius(16)
        .overlay(
          RoundedRectangle(cornerRadius: 16)
            .stroke(
              selectedIcon == nil ? Color.blue : Color.clear,
              lineWidth: 5
            )
        )
        .onTapGesture {
          selectedIcon = nil
          setAppIcon(nil)
        }

      Image("rainbow-icon-png")
        .resizable()
        .frame(width: 80, height: 80)
        .cornerRadius(16)
        .overlay(
          RoundedRectangle(cornerRadius: 16)
            .stroke(
              selectedIcon == "rainbow-icon" ? Color.blue : Color.clear,
              lineWidth: 5
            )
        )
        .onTapGesture {
          selectedIcon = "rainbow-icon"
          setAppIcon("rainbow-icon")
        }

      Image("pumpkin-icon-png")
        .resizable()
        .frame(width: 80, height: 80)
        .cornerRadius(16)
        .overlay(
          RoundedRectangle(cornerRadius: 16)
            .stroke(
              selectedIcon == "pumpkin-icon" ? Color.blue : Color.clear,
              lineWidth: 5
            )
        )
        .onTapGesture {
          selectedIcon = "pumpkin-icon"
          setAppIcon("pumpkin-icon")
        }
    }
    .frame(maxWidth: .infinity)
    .padding()
    .navigationTitle("App Icon")
    .navigationBarTitleDisplayMode(.inline)
  }

  /// Set app icon. Call with nil as the icon name to reset the app icon to default.
  private func setAppIcon(_ iconName: String?) {
    guard UIApplication.shared.alternateIconName != iconName else { return }

    if let iconName {
      print("changing app icon to \(iconName)")
      UIApplication.shared.setAlternateIconName(iconName) { error in
        if let error {
          print("Error setting alternate icon: \(error)")
        }
      }
    }
  }
}

#Preview {
  AppIconPickerView()
}
