import SwiftUI

struct StandalonePostView: View {
  let postId: Int

  @StateObject var viewModel: ViewModel

  init(postId: Int) {
    self.postId = postId
    _viewModel = StateObject(wrappedValue: ViewModel(postId: postId))
  }

  init(postId: Int, viewModel: ViewModel) {
    self.postId = postId
    _viewModel = StateObject(wrappedValue: viewModel)
  }

  var body: some View {
    ScrollView {
      switch viewModel.post {
      case .idle:
        Color.clear
      case .loading:
        ProgressView()
      case .loaded(let detailedPost):
        VStack {
          PostView(post: detailedPost, isStandalone: true)
          CommentsView(postId: postId, isShowingInSheet: false)
        }
      case .failed(let error):
        VStack {
          Text("Something went wrong")
            .font(.title3)
            .fontWeight(.bold)
            .padding()
          Text(error.localizedDescription)
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(.red)
          Image(systemName: "arrow.clockwise")
            .imageScale(.large)
            .onTapGesture {
              Task { @MainActor in
                await viewModel.load()
              }
            }
            .padding()
        }
      }
    }
    .refreshable(action: {
      Task { await viewModel.load() }
    })
    .task {
      await viewModel.load()
    }
  }
}
