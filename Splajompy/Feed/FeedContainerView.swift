import SwiftUI

struct FeedContainerView: View {
  @State private var filterState = FilterState()
  @State private var path = NavigationPath()
  @State private var isShowingNewPostView = false
  @EnvironmentObject private var feedRefreshManager: FeedRefreshManager

  init() {
    let savedState = UserDefaults.standard.data(forKey: "feedFilterState")
    if let savedState = savedState,
      let decodedState = try? JSONDecoder().decode(
        FilterState.self,
        from: savedState
      )
    {
      _filterState = State(initialValue: decodedState)
    }
  }

  private func saveFilterState(_ state: FilterState) {
    if let encoded = try? JSONEncoder().encode(state) {
      UserDefaults.standard.set(encoded, forKey: "feedFilterState")
    }
  }

  var body: some View {
    NavigationStack(path: $path) {
      ScrollView {
        FeedView(feedType: filterState.mode == .all ? .all : .home)
          .id(filterState.mode)  // Force view refresh
          .navigationBarTitleDisplayMode(.inline)
          .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
              Image("Full_Logo")
                .resizable()
                .scaledToFit()
                .frame(height: 30)
            }

            ToolbarItem(placement: .principal) {
              Menu {
                Button {
                  withAnimation(.snappy) {
                    filterState.mode = .all
                    saveFilterState(filterState)
                  }
                } label: {
                  HStack {
                    Text("All")
                    if filterState.mode == .all {
                      Image(systemName: "checkmark")
                    }
                  }
                }

                Button {
                  withAnimation(.snappy) {
                    filterState.mode = .following
                    saveFilterState(filterState)
                  }
                } label: {
                  HStack {
                    Text("Following")
                    if filterState.mode == .following {
                      Image(systemName: "checkmark")
                    }
                  }
                }
              } label: {
                HStack {
                  Text(filterState.mode == .all ? "All" : "Following")
                  Image(systemName: "chevron.down")
                    .font(.caption)
                }
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .padding(.vertical, 5)
                .padding(.horizontal, 10)
                .background(
                  RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
                    .background(Color.clear)
                )
              }
              .menuStyle(BorderlessButtonMenuStyle())
            }

            ToolbarItem(placement: .navigationBarTrailing) {
              Button(action: { isShowingNewPostView = true }) {
                Image(systemName: "plus")
              }
              .buttonStyle(.plain)
            }
          }
          .navigationDestination(for: Route.self) { route in
            switch route {
            case .profile(let id, let username):
              ProfileView(userId: Int(id)!, username: username)
            }
          }
          .onOpenURL { url in
            print("on open url: \(url)")
            if let route = parseDeepLink(url) {
              path.append(route)
            }
          }
      }
      .refreshable {
        feedRefreshManager.triggerRefresh()
      }
    }
    .sheet(isPresented: $isShowingNewPostView) {
      NewPostView(
        onPostCreated: { feedRefreshManager.triggerRefresh() }
      )
      .interactiveDismissDisabled()
    }
  }
}
