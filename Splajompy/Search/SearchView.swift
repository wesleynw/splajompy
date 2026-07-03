import SwiftUI

struct SearchView: View {
  @State private var viewModel: ViewModel = ViewModel()
  @FocusState private var isSearchBarFocused: Bool
  @State private var searchText = ""
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
          source: "SearchView",
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
    .pageTitle("Search", placement: .leading)
    #if os(macOS)
      .frame(maxWidth: 600)
      .frame(maxWidth: .infinity)
    #endif
    #if os(macOS)
      .contentMargins(.horizontal, 40, for: .scrollContent)
      .safeAreaPadding(.horizontal, 20)
    #endif
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
  }

  private var emptyState: some View {
    VStack {
      Image("snail-search")
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 200, height: 200)
    }
  }

  private var noResultsState: some View {
    VStack {
      Image("snail-outline")
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 200, height: 200)
      Text("No one's here")
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
            value: Route.profile(
              id: String(user.userId),
              username: user.username
            )
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
    .scrollContentBackground(.hidden)
  }
}

#Preview {
  SearchView()
}
