import SwiftUI

struct SearchView: View {
  @StateObject private var viewModel: ViewModel
  @State private var searchText = ""

  init() {
    _viewModel = StateObject(wrappedValue: ViewModel())
  }

  var body: some View {
    Group {
      if viewModel.isLoading {
        ProgressView()
          .scaleEffect(1.5)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if searchText.isEmpty {
        emptyState
      } else if viewModel.searchResults.isEmpty {
        noResultsState
      } else {
        searchResults
      }
    }
    #if os(macOS)
      .contentMargins(.horizontal, 40, for: .scrollContent)
      .safeAreaPadding(.horizontal, 20)
    #endif
    .navigationTitle("Search")
    .searchable(text: $searchText, prompt: "People...")
    .autocorrectionDisabled()
    .onSubmit(of: .search) {
      if !searchText.isEmpty {
        viewModel.searchUsers(prefix: searchText.lowercased())
      }
    }
    .onChange(of: searchText) { _, newValue in
      if newValue.count >= 1 {
        viewModel.searchUsers(prefix: newValue.lowercased())
      } else {
        viewModel.clearResults()
      }
    }
  }

  private var emptyState: some View {
    VStack(spacing: 16) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 48))
        .foregroundColor(.gray)
      Text("Search for Splajompians")
        .font(.title3)
        .fontWeight(.bold)
      Text("Type a username to find others.")
        .foregroundColor(.gray)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
  }

  private var searchResults: some View {
    List(viewModel.searchResults, id: \.userId) { user in
      NavigationLink(
        value: Route.profile(id: String(user.userId), username: user.username)
      ) {
        HStack {
          VStack(alignment: .leading, spacing: 2) {
            if let displayName = user.name, !displayName.isEmpty {
              Text(displayName)
                .font(.headline)
                .fontWeight(.bold)
                .lineLimit(1)

              Text("@\(user.username)")
                .font(.subheadline)
                .foregroundColor(.gray)
            } else {
              Text("@\(user.username)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.gray)
            }
          }
          Spacer()
        }
        .padding(.vertical, 8)
      }
    }
    .listStyle(.plain)
  }
}
