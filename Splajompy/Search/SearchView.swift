import SwiftUI

struct SearchView: View {
  @StateObject private var viewModel: ViewModel
  @State private var searchText = ""
  @FocusState private var isSearchFocused: Bool

  init() {
    _viewModel = StateObject(wrappedValue: ViewModel())
  }

  var body: some View {
    ZStack {
      Color.clear
        .contentShape(Rectangle())
        .onTapGesture {
          isSearchFocused = false
        }
        .gesture(
          DragGesture(minimumDistance: 10)
            .onEnded { gesture in
              if gesture.translation.height > 0 {
                isSearchFocused = false
              }
            }
        )

      VStack(spacing: 0) {
        searchBar

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
    }
    .frame(maxHeight: .infinity)
    .navigationTitle("Search")
  }

  private var searchBar: some View {
    HStack {
      Image(systemName: "magnifyingglass")
        .foregroundColor(.gray)

      TextField("Search users...", text: $searchText)
        .textFieldStyle(.plain)
        .autocapitalization(.none)
        .autocorrectionDisabled()
        .focused($isSearchFocused)
        .onChange(of: searchText) { _, newValue in
          if newValue.count >= 1 {
            viewModel.searchUsers(prefix: newValue)
          } else {
            viewModel.clearResults()
          }
        }

      if !searchText.isEmpty {
        Button(action: {
          searchText = ""
          viewModel.clearResults()
        }) {
          Image(systemName: "xmark.circle.fill")
            .foregroundColor(.gray)
        }
      }
    }
    .padding(12)
    .background(
      RoundedRectangle(cornerRadius: 8)
        .stroke(
          isSearchFocused ? Color.primary : Color.gray.opacity(0.75),
          lineWidth: 2
        )
    )
    .padding()
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
