import SwiftUI

struct AppearanceSwitcher: View {
  @AppStorage("appearance_mode") var appearanceMode: String = "Automatic"
  @AppStorage("comment_sort_order") private var commentSortOrder: String = "Newest First"

  let options = ["Automatic", "Light", "Dark"]

  var body: some View {
    List {
      Section {
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
      } header: {
        Text("Theme")
      }

      Section {
        HStack {
          Text("Comment Sort Order")
          Spacer()
          Picker("Comment Sort Order", selection: $commentSortOrder) {
            Text("Newest First").tag("Newest First")
            Text("Oldest First").tag("Oldest First")
          }
          .pickerStyle(.menu)
          .labelsHidden()
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
