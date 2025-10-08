import SwiftUI

struct SecretPageView: View {
  var body: some View {
    VStack {
      Image(systemName: "laurel.leading.laurel.trailing")
        .font(.largeTitle)
      Text("This is the secret page.")
        .font(.title2)
        .fontWeight(.bold)
        .padding()
      Text("Few can see the secret page.")
        .fontWeight(.bold)
        .padding()

      Text(
        "Please do not discuss the secret page amongst yourselves. You may disable the secret page in Settings should you find it a hinderance."
      )
      .padding()
    }
    .padding()
    .multilineTextAlignment(.center)
    .navigationTitle("Secret Page")
  }
}

#Preview {
  NavigationStack {
    SecretPageView()
  }
}
