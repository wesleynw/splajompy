import SwiftUI

struct MostLikedPostView: View {
  var data: WrappedData
  var onContinue: () -> Void
  @State private var isShowingPost: Bool = false
  @State private var isShowingContinueButton: Bool = false

  var body: some View {
    VStack {
      if !isShowingPost {
        Text("One post stood out in particular this year")
          .font(.title2)
          .fontDesign(.rounded)
          .fontWeight(.bold)
          .multilineTextAlignment(.center)
          .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
              withAnimation {
                isShowingPost = true
              }
            }
          }
      } else {
        ScrollView {
          Text("Your top post")
            .font(.title2)
            .fontWeight(.black)
            .fontDesign(.rounded)
            .padding()

          PostView(post: data.mostLikedPost, postManager: PostManager())
        }
        .onAppear {
          DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            withAnimation {
              isShowingContinueButton = true
            }
          }
        }
      }
    }
    .padding()
    .overlay(alignment: .bottom) {
      if isShowingContinueButton {
        Button("Continue") {
          onContinue()
        }
        .fontWeight(.bold)
        .modify {
          if #available(iOS 26, *) {
            $0.buttonStyle(.glassProminent)
          } else {
            $0.buttonStyle(.borderedProminent)
          }
        }
      }
    }
  }
}

#Preview {
  NavigationStack {
    MostLikedPostView(
      data: Mocks.wrappedData,
      onContinue: { print("continue") }
    )
    .environmentObject(AuthManager())
  }
}
