import SwiftUI

struct FeedContainerView: View {
  @State private var filterState = FilterState()
  @State private var path = NavigationPath()
  @State private var isShowingNewPostView = false
  @EnvironmentObject private var feedRefreshManager: FeedRefreshManager
  var body: some View {
    NavigationStack(path: $path) {
      ScrollView {
        //        HStack {
        //          Image("Full_Logo")
        //            .resizable()
        //            .scaledToFit()
        //            .containerRelativeFrame(.horizontal) { size, axes in
        //              size * 0.5
        //            }
        //
        //          Spacer()
        //        }
        //        .padding()

        HStack {
          DrilldownFilter(filterState: $filterState)
            .padding(0)

          Spacer()
        }
        .padding(0)
        FeedView(feedType: filterState.mode == .all ? .all : .home)
          .id(filterState.mode)  // Force view refresh
          .navigationBarTitleDisplayMode(.inline)
          .toolbar {
            //            ToolbarItem(placement: .navigationBarLeading) {
            //              Spacer()
            //            }

            ToolbarItem(placement: .navigationBarLeading) {
              Image("Full_Logo")
                .resizable()
                .scaledToFit()
                .frame(height: 30)
            }

            ToolbarItem(placement: .navigationBarTrailing) {
              Button(action: { isShowingNewPostView = true }) {
                Image(systemName: "plus")
              }
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
