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
        .tag(FeedType.home)

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
    } label: {
      HStack {
        Text("Splajompy")
          .font(.title2)
          .fontWeight(.black)

        Image(systemName: "chevron.down")
          .font(.caption)
      }
      .tint(.primary)
    }
    .buttonStyle(.plain)
    .menuIndicator(.visible)
  }

  @ViewBuilder
  private var feedMenuButtons: some View {
    Button {
      selectedFeedType = .mutual
    } label: {
      HStack {
        Text("Home")
        if selectedFeedType == .mutual {
          Image(systemName: "checkmark")
        }
      }
    }
    Button {
      selectedFeedType = .following
    } label: {
      HStack {
        Text("Following")
        if selectedFeedType == .following {
          Image(systemName: "checkmark")
        }
      }
    }
    Button {
      selectedFeedType = .all
    } label: {
      HStack {
        Text("All")
        if selectedFeedType == .all {
          Image(systemName: "checkmark")
        }
      }
    }
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
