import SwiftUI

struct MostLikedPostView: View {
  var data: WrappedData
  @State private var isShowingPost: Bool = false

  var body: some View {
    VStack {
      if !isShowingPost {
        Text("Throughout the year, one post in particular stood out.")
          .font(.title)
          .fontDesign(.rounded)
          .fontWeight(.bold)
          .multilineTextAlignment(.center)
          .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
              withAnimation {
                isShowingPost = true
              }
            }
          }
      } else {
        ScrollView {
          Text("Your top post")
            .font(.title)
            .fontWeight(.black)
            .fontDesign(.rounded)
            .padding()
          
          PostView(post: data.mostLikedPost, postManager: PostManager())
        }
      }
    }
    .padding()
  }
}

#Preview {
  NavigationStack {
    MostLikedPostView(data: Mocks.wrappedData)
      .environmentObject(AuthManager())
  }
}
