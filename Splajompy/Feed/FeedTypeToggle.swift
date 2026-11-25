import SwiftUI

struct FeedTypeToggle: View {
  @Binding var selectedFeedType: FeedType

  var body: some View {
    Menu {
      Picker("Feed Type", selection: $selectedFeedType) {
        Button {
        } label: {
          Label("Home", systemImage: "house")
            .font(SFont.sized(to: .body, weight: .bold))
          Text("Following plus a few others")
            .font(SFont.sized(to: .body, weight: .body))
        }
        .tag(FeedType.mutual)

        Button {
        } label: {
          Label("Following", systemImage: "person.3")
            .font(SFont.sized(to: .body, weight: .bold))
          Text("People that you follow")
            .font(SFont.sized(to: .body, weight: .body))
        }
        .tag(FeedType.following)

        Button {
        } label: {
          Label("Everyone", systemImage: "globe")
            .font(SFont.sized(to: .body, weight: .bold))
          Text("Beware")
            .font(SFont.sized(to: .body, weight: .body))
        }
        .tag(FeedType.all)

      }
    } label: {
      HStack {
        #if os(iOS)
          Image("snail-small-template")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 30, height: 30)
            .padding(.trailing, -5)
        #endif
        Text("Splajompy")
          .font(SFont.title)
      }
    }
    #if os(macOS)
      .pickerStyle(.inline)
    #endif
    .foregroundStyle(.primary)
  }
}

#Preview {
  @Previewable @State var selectedFeedType: FeedType = .all

  NavigationStack {
    Color.clear
      .toolbar {
        ToolbarItem(placement: .automatic) {
          FeedTypeToggle(selectedFeedType: $selectedFeedType)
        }
      }
  }
}
