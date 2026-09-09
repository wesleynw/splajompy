import SwiftUI

struct PartyInviteView: View {
  var onDismiss: () -> Void
  @Environment(\.openURL) var openURL

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack {
          Text("GET SLIMY")
            .fontWeight(.semibold)
            .font(SJFont.title)
            .padding(.bottom, 5)

          Text("WITH US AT THE SPLAJOMPARTY")
            .fontWeight(.semibold)
            .font(SJFont.heading)
            .padding()

          Image("party-invite")
            .resizable()
            .aspectRatio(contentMode: .fit)
        }
        .padding()
        .multilineTextAlignment(.center)
      }
      .padding()
      .safeAreaInset(edge: .bottom) {
        Button {
          openURL(
            URL(
              string: "https://partiful.com/e/73mypHJn5HJSErnPgqTR?c=bQHVrVKw"
            )!
          )
        } label: {
          HStack {
            Image(systemName: "link")
            Text("if you say so")
          }
        }
        .buttonStyle(.borderedProminent)
      }
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          if #available(iOS 26, macOS 26, *) {
            Button(role: .close) {
              onDismiss()
            }
          } else {
            Button("No thanks") {
              onDismiss()
            }
          }
        }
      }
    }
  }
}

#Preview {
  Text("")
    .sheet(isPresented: .constant(true)) {
      PartyInviteView(onDismiss: {})
    }
}
