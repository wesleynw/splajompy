import PostHog
import SwiftUI

struct SearchView: View {
  @State private var viewModel: ViewModel = ViewModel()
  @FocusState private var isSearchBarFocused: Bool
  @State private var searchText = ""
  @State private var scrollOffset = CGFloat.zero

  var onUserSelected: ((PublicUser) -> Void)?

  var body: some View {
    Group {
      switch viewModel.state {
      case .idle:
        emptyState
      case .loading:
        ProgressView()
          #if os(macOS)
            .controlSize(.small)
          #endif
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      case .error(let error):
        ErrorScreen(
          errorString: error.localizedDescription,
          onRetry: { await viewModel.searchUsers(prefix: searchText) }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      case .loaded(let results):
        if results.isEmpty {
          noResultsState
        } else {
          searchResults(users: results)
        }
      }
    }
    #if os(macOS)
      .frame(maxWidth: 600)
      .frame(maxWidth: .infinity)
    #endif
    #if os(macOS)
      .contentMargins(.horizontal, 40, for: .scrollContent)
      .safeAreaPadding(.horizontal, 20)
      .toolbar(removing: .title)
    #endif
    .toolbar {
      if #available(iOS 26, macOS 26, *) {
        #if os(iOS)
          ToolbarItem(placement: .topBarLeading) {
            Text("Search")
              .font(.title2)
              .fontWeight(.black)
              .fixedSize()
          }
          .sharedBackgroundVisibility(.hidden)
        #else
          ToolbarItem(placement: .principal) {
            Text("Search")
              .font(.title2)
              .fontWeight(.black)
              .fixedSize()
          }
          .sharedBackgroundVisibility(.hidden)
        #endif
      } else {
        #if os(iOS)
          ToolbarItem(placement: .topBarLeading) {
            Text("Search")
              .font(.title2)
              .fontWeight(.black)
              .fixedSize()
          }
        #else
          ToolbarItem(placement: .principal) {
            Text("Search")
              .font(.title2)
              .fontWeight(.black)
              .fixedSize()
          }
        #endif
      }
    }
    .searchable(
      text: $searchText,
      placement: {
        #if os(iOS)
          .navigationBarDrawer(displayMode: .always)
        #else
          .toolbar
        #endif
      }()
    )
    .modify {
      if #available(iOS 26, *) {
        $0.searchFocused($isSearchBarFocused)
      }
    }
    .autocorrectionDisabled()
    .onSubmit(of: .search) {
      if !searchText.isEmpty {
        Task {
          await viewModel.searchUsers(prefix: searchText.lowercased())
        }
      }
    }
    .onChange(of: searchText) { _, newValue in
      if newValue.count >= 1 {
        Task {
          await viewModel.searchUsers(prefix: newValue.lowercased())
        }
      } else {
        viewModel.clearResults()
      }
    }
    .modify {
      if #available(iOS 26, *),
        PostHogSDK.shared.isFeatureEnabled("toolbar-scroll-effect")
      {
        $0.scrollFadeBackground(scrollOffset: scrollOffset)
      }
    }
    //    .onTapGesture {
    //      isSearchBarFocused = false
    //    }
  }

  private var emptyState: some View {
    VStack(spacing: 16) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 48))
        .foregroundColor(.gray)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .contentShape(Rectangle())
  }

  private var noResultsState: some View {
    VStack(spacing: 16) {
      Image(systemName: "person.slash")
        .font(.system(size: 48))
        .foregroundColor(.gray)
      Text("No Splajompians found")
        .font(.title3)
        .fontWeight(.bold)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .contentShape(Rectangle())
  }

  private func searchResults(users: [PublicUser]) -> some View {
    List {
      ForEach(users, id: \.userId) { user in
        if let onUserSelected {
          Button {
            onUserSelected(user)
          } label: {
            HStack {
              ProfileDisplayNameView(user: user, alignVertically: false)
              if user.isFriend == true {
                Image(systemName: "star.circle.fill")
                  .foregroundStyle(.green)
                  .font(.caption)
              }
              Spacer()
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
        } else {
          NavigationLink(
            value: Route.profile(id: String(user.userId), username: user.username)
          ) {
            HStack {
              ProfileDisplayNameView(user: user, alignVertically: false)
              Spacer()
            }
            .padding(.vertical, 8)
          }
        }
      }
    }
    .listStyle(.plain)
    .modify {
      if #available(iOS 26, *),
        PostHogSDK.shared.isFeatureEnabled("toolbar-scroll-effect")
      {
        $0.scrollFadeEffect(scrollOffset: $scrollOffset)
      }
    }
  }
}
