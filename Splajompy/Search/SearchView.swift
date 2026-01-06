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
    .toolbar {
      if #available(iOS 26, macOS 26, *) {
        ToolbarItem(placement: .topBarLeading) {
          Text("Search")
            .font(.title2)
            .fontWeight(.black)
            .fixedSize()
        }
        .sharedBackgroundVisibility(.hidden)
      } else {
        ToolbarItem(placement: .topBarLeading) {
          Text("Search")
            .font(.title2)
            .fontWeight(.black)
            .fixedSize()
        }
      }
    }
    .modify {
      if #available(iOS 16, macOS 13, *) {
        $0.toolbarBackground(.visible, for: .navigationBar)
          .toolbarBackground(.blue.gradient.opacity(0.5), for: .navigationBar)
      } else {
        $0
      }
    }
    .modify {
      if #available(iOS 18, *) {
        $0.toolbarBackgroundVisibility(.visible, for: .navigationBar)
      } else {
        $0
      }
    }
    .searchable(text: $searchText)
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
          HStack(alignment: .firstTextBaseline, spacing: 2) {
            ProfileDisplayNameView(user: user, alignVertically: false)
          }
          Spacer()
        }
        .padding(.vertical, 8)
      }
    }
    .listStyle(.plain)
  }
}

#Preview {
  NavigationStack {
    SearchView()
  }
}
