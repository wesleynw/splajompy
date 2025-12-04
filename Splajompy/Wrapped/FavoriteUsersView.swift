import SwiftUI

struct FavoriteUsersView: View {
  var data: WrappedData
  var onContinue: () -> Void
  @State private var isShowingIntroText: Bool = true
  @State private var isShowingContinueButton: Bool = false
  @State private var visibleRowCount: Int = 0

  var body: some View {
    VStack {
      Text(
        "Your favorite people"
      )
      .font(.title)
      .fontDesign(.rounded)
      .fontWeight(.bold)
      .multilineTextAlignment(.center)
      .padding()
      .onAppear {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
          withAnimation {
            isShowingIntroText = false
          }
          for index in 0..<data.favoriteUsers.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) + 1) {
              if visibleRowCount <= index {
                withAnimation(.bouncy) {
                  visibleRowCount = index + 1
                }
              }
            }
          }

          DispatchQueue.main.asyncAfter(
            deadline: .now() + Double(data.favoriteUsers.count) + 2
          ) {
            withAnimation {
              isShowingContinueButton = true
            }
          }
        }
      }
      .transition(.blurReplace)

      if isShowingIntroText {
        Text("on Splajompy")
          .font(.title)
          .fontDesign(.rounded)
          .fontWeight(.bold)
          .multilineTextAlignment(.center)
      }

      if !isShowingIntroText {
        ForEach(Array(data.favoriteUsers.enumerated()), id: \.offset) {
          index,
          data in
          if index < visibleRowCount {
            HStack {
              Text("\(index + 1).")
                .font(.title3)
                .fontDesign(.rounded)
                .fontWeight(.black)

              ProfileDisplayNameView(
                user: data.user,
                largeTitle: false,
                showUsername: true,
                alignVertically: false
              )
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
              GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 20.0)
                  .fill(.blue.gradient.secondary)
                  .frame(width: geometry.size.width * data.proportion / 100)
              }
            }
          }
        }
        .padding(.horizontal)
      }
    }
    .frame(maxHeight: .infinity)
    .overlay(alignment: .bottom) {
      if isShowingContinueButton {
        Button("Continue") {
          onContinue()
        }
        .buttonStyle(.borderedProminent)
      }
    }
  }
}

#Preview {
  FavoriteUsersView(data: Mocks.wrappedData, onContinue: {})
}
