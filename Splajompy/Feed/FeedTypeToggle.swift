import SwiftUI

struct FeedTypeToggle: View {
  @Binding var selectedFeedType: FeedType

  var body: some View {
    Menu {
      Picker("Feed Type", selection: $selectedFeedType) {
        Button {
        } label: {
          Label("Home", systemImage: "house")
          Text("Follwing plus a few others")
        }
        .tag(FeedType.mutual)

        Button {
        } label: {
          Label("Following", systemImage: "person.3")
          Text("People that you follow")
        }
        .tag(FeedType.following)

        Button {
        } label: {
          Label("Everyone", systemImage: "globe")
          Text("Beware")
        }
        .tag(FeedType.all)

      }
      .pickerStyle(.inline)
    } label: {
      HStack {
        Image("snail-mini-template")
          .resizable()
          .foregroundStyle(.primary)
          .aspectRatio(contentMode: .fit)
          .frame(width: 30, height: 30)
          .padding(.trailing, -5)
        Text("Splajompy")
          .font(.title2)
          .fontWeight(.black)

        #if os(iOS)
          Image(systemName: "chevron.down")
            .font(.caption)
        #endif
      }
    }
    .buttonStyle(.plain)
    .menuIndicator(.visible)
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
