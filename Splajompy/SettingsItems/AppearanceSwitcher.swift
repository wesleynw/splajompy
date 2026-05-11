import PostHog
import SwiftUI

struct AppearanceSwitcher: View {
  @AppStorage("meme_onion_style") var onionStyle: Int = 0
  @AppStorage("meme_pickles_included") var picklesIncluded: Bool = true
  @AppStorage("meme_sauce_amount") var sauceAmount: Int = 1

  @AppStorage("appearance_mode") var appearanceMode: String = "Automatic"
  @AppStorage("comment_sort_order") private var commentSortOrder: String =
    "Newest First"
  @AppStorage("image_layout_preference") private var imageLayoutPreference: ImageLayoutPreference =
    .undecided

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
      }

      Section {
        Picker("Comment Sort Order", selection: $commentSortOrder) {
          Text("Newest First").tag("Newest First")
          Text("Oldest First").tag("Oldest First")
        }
      }

      #if os(iOS)
        if imageLayoutPreference != .undecided {
          Section {
            Picker("Image Layout", selection: $imageLayoutPreference) {
              Text("Carousel").tag(ImageLayoutPreference.carousel)
              Text("Grid").tag(ImageLayoutPreference.grid)
            }
          }
        }
      #endif

      Section {
        Picker("Onion Style", selection: $onionStyle) {
          Text("Grilled").tag(0)
          Text("Normal")
        }

        Toggle(isOn: $picklesIncluded) {
          Text("Pickles")
        }

        Stepper(
          "Splajompy Sauce: \(sauceAmount)",
          onIncrement: { sauceAmount += 1 },
          onDecrement: { if sauceAmount > 0 { sauceAmount -= 1 } },
        )
      }
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
