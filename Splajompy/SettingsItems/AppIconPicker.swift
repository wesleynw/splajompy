import SwiftUI

struct AppIconPickerView: View {
  @State private var selectedIcon: String?

  init() {
    _selectedIcon = State(initialValue: UIApplication.shared.alternateIconName)
  }

  var body: some View {
    HStack(spacing: 20) {
      Image("Image_AppIcon")
        .resizable()
        .frame(width: 80, height: 80)
        .cornerRadius(16)
        .overlay(
          RoundedRectangle(cornerRadius: 16)
            .stroke(
              selectedIcon == nil ? Color.blue : Color.clear,
              lineWidth: 3
            )
        )
        .onTapGesture {
          selectedIcon = nil
          setAppIcon(nil)
        }

      Image("Image_AppIcon 1")
        .resizable()
        .frame(width: 80, height: 80)
        .cornerRadius(16)
        .overlay(
          RoundedRectangle(cornerRadius: 16)
            .stroke(
              selectedIcon == "AppIcon 1" ? Color.blue : Color.clear,
              lineWidth: 3
            )
        )
        .onTapGesture {
          selectedIcon = "AppIcon 1"
          setAppIcon("AppIcon 1")
        }

      Image("halloween_logo")
        .resizable()
        .frame(width: 80, height: 80)
        .cornerRadius(16)
        .overlay(
          RoundedRectangle(cornerRadius: 16)
            .stroke(
              selectedIcon == "halloween_app_icon" ? Color.blue : Color.clear,
              lineWidth: 3
            )
        )
        .onTapGesture {
          selectedIcon = "halloween_app_icon"
          setAppIcon("halloween_app_icon")
        }
    }
    .frame(maxWidth: .infinity)
    .padding()
    .navigationTitle("App Icon")
    .navigationBarTitleDisplayMode(.inline)
  }

  private func setAppIcon(_ iconName: String?) {
    guard UIApplication.shared.alternateIconName != iconName else { return }

    UIApplication.shared.setAlternateIconName(iconName) { error in
      if let error = error {
        print("Error setting alternate icon: \(error.localizedDescription)")
      }
    }
  }
}

#Preview {
  AppIconPickerView()
}
