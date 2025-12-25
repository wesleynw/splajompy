import SwiftUI

struct TotalWordCountView: View {
  var data: WrappedData
  var onContinue: () -> Void
  @State private var isShowingContinueButton: Bool = false
  @State private var isShowingIntroText: Bool = true

  var body: some View {
    ZStack {
      LinedPaperBackground()

      VStack(alignment: .leading) {
        Text(
          data.totalWordCount > 100
            ? "You had a lot to say this year..."
            : "You didn't have a lot to say this year..."
        )
        .padding(.vertical)
        .onAppear {
          DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation {
              isShowingIntroText = false
            }
          }

          DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            withAnimation {
              isShowingContinueButton = true
            }
          }
        }

        HStack {
          Text("You wrote ")
            + Text(data.totalWordCount.formatted()).foregroundStyle(.blue)
            + Text(" words on Splajompy")
        }
        .opacity(isShowingIntroText ? 0 : 1)
      }
      .lineLimit(nil)
      .frame(maxWidth: .infinity)
      .multilineTextAlignment(.leading)
      .fontDesign(.serif)
      .font(.title)
      .padding(.leading, 60)
      .padding(.trailing)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .foregroundStyle(.black)
    .preferredColorScheme(.light)
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

struct LinedPaperBackground: View {

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        Color(red: 0.98, green: 0.97, blue: 0.93)

        VStack(spacing: 0) {
          ForEach(0..<100, id: \.self) { _ in
            Rectangle()
              .fill(Color(red: 0.7, green: 0.85, blue: 0.95))
              .frame(height: 1)
            Spacer()
              .frame(height: 31)
          }
        }
        .offset(y: -32)

        Rectangle()
          .fill(Color(red: 0.95, green: 0.4, blue: 0.4))
          .frame(width: 2)
          .offset(x: -geometry.size.width / 2 + 60)

      }
      .ignoresSafeArea()
    }
  }
}

#Preview {
  TotalWordCountView(data: Mocks.wrappedData, onContinue: {})
}
