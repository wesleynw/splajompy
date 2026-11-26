import SwiftUI

struct NoCommentsView: View {

  var body: some View {
    VStack {
      Image("snail-sleeping")
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 280, height: 200)

      Text("No comments")
        .font(SFont.sized(to: .title2, weight: .bold))
        .foregroundStyle(.secondary)
    }
    .padding(.bottom, 40)
  }
}
