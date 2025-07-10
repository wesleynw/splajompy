import SwiftUI

struct AppearanceSwitcher: View {
  @AppStorage("appearance_mode") var appearanceMode: String = "Automatic"

  let options = ["Automatic", "Light", "Dark"]

  var body: some View {
    List {
      ForEach(options, id: \.self) { option in
        HStack {
          Text(option)
          Spacer()
          if option == appearanceMode {
            Image(systemName: "checkmark")
              .foregroundColor(.accentColor)
          }
        }
        .contentShape(.rect)
        .onTapGesture {
          appearanceMode = option
        }
      }
    }
    .navigationTitle("Appearance")
    #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
    #endif
  }
}

#Preview {
  NavigationStack {
    AppearanceSwitcher()
  }
}
