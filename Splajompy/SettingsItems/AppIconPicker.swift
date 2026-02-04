import SwiftUI

struct AppIconPickerView: View {
  @State private var selectedIcon: String?

  init() {
    _selectedIcon = State(initialValue: UIApplication.shared.alternateIconName)
  }

  var body: some View {
    ScrollView {
      LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
        iconCell(image: "icon-png", iconName: nil)
        iconCell(image: "rainbow-icon-png", iconName: "rainbow-icon")
        iconCell(image: "pumpkin-icon-png", iconName: "pumpkin-icon")
        iconCell(image: "exploding-icon-png", iconName: "exploding-icon")
      }
      .padding()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .navigationTitle("App Icon")
    .navigationBarTitleDisplayMode(.inline)
  }

  private func iconCell(image: String, iconName: String?) -> some View {
    Color.clear
      .aspectRatio(1, contentMode: .fit)
      .background(.thinMaterial)
      .clipShape(RoundedRectangle(cornerRadius: 16))
      .overlay(
        Image(image)
          .resizable()
          .frame(width: 100, height: 100)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 16)
          .stroke(
            selectedIcon == iconName ? Color.blue : Color.clear,
            lineWidth: 3
          )
      )
      .onTapGesture {
        selectedIcon = iconName
        setAppIcon(iconName)
      }
  }

  /// Set app icon. Call with nil as the icon name to reset the app icon to default.
  private func setAppIcon(_ iconName: String?) {
    guard UIApplication.shared.alternateIconName != iconName else { return }

    UIApplication.shared.setAlternateIconName(iconName) { error in
      if let error {
        print("Error setting alternate icon: \(error)")
      }
    }
  }
}

#Preview {
  NavigationStack {
    AppIconPickerView()
  }
}
