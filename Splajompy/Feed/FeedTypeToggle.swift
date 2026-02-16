import SwiftUI

/// Displays app title and opens a menu to toggle the feed type.
struct FeedTypeToggle: ToolbarContent {
  @Binding var selectedFeedType: FeedType

  var body: some ToolbarContent {
    #if os(macOS)
      if #available(macOS 26, *) {
        toolbarItem.sharedBackgroundVisibility(.hidden)
      } else {
        toolbarItem
      }
    #else
      toolbarItem
    #endif
  }

  private var toolbarItem: some ToolbarContent {
    ToolbarItem(
      placement: {
        #if os(iOS)
          .topBarLeading
        #else
          .principal
        #endif
      }()
    ) {
      menuContent
    }
  }

  @ViewBuilder
  private var menuContent: some View {
    #if os(iOS)
      Menu {
        feedMenuButtons
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
    #else
      Menu {
        feedMenuButtons
      } label: {
        HStack {
          Text("Splajompy")
            .font(.title2)
            .fontWeight(.black)
        }
        .tint(.primary)
      }
      .buttonStyle(.plain)
      .menuIndicator(.visible)
    #endif
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
        FeedTypeToggle(selectedFeedType: $selectedFeedType)
      }
  }
}
