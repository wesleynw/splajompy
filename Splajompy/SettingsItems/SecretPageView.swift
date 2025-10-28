import SwiftUI

struct SecretPageView: View {
  var body: some View {
    VStack {
      Image(systemName: "fossil.shell")
        .font(.largeTitle)
      Text("This is the secret page.")
        .font(.title2)
        .fontWeight(.bold)
        .padding()

      Text(
        "Please do not discuss the secret page amongst yourselves. "
      )
      .padding()
    }
    .padding()
    .multilineTextAlignment(.center)
    .navigationTitle("Secret Page")
    #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
    #endif
  }
}

#Preview {
  NavigationStack {
    SecretPageView()
  }
}
