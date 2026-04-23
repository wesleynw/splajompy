import PostHog
import SwiftUI

struct AppearanceSwitcher: View {
  @AppStorage("appearance_mode") var appearanceMode: String = "Automatic"
  @AppStorage("comment_sort_order") private var commentSortOrder: String =
    "Newest First"
  @AppStorage("image_layout_carousel") private var useCarousel: Bool = true

  let options = ["Automatic", "Light", "Dark"]

  var body: some View {
    List {
      Section {
        ForEach(options, id: \.self) { (option: String) in
          Button {
            appearanceMode = option
          } label: {
            HStack {
              Text(option)
              Spacer()
              if option == appearanceMode {
                Image(systemName: "checkmark")
                  .foregroundStyle(Color.accentColor)
              }
            }
          }
          .foregroundStyle(.primary)
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

      #if os(iOS)
        Section {
          Picker("Image Style", selection: $useCarousel) {
            Text("Carousel").tag(true)
            Text("Grid").tag(false)
          }
        }
      #endif
    }
    .navigationTitle("Appearance")
    #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
    #endif
    .postHogScreenView()
  }
}

#Preview {
  NavigationStack {
    AppearanceSwitcher()
  }
}
