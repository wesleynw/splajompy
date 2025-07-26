import SwiftUI

struct RequestFeatureView: View {
  @State var featureText: String = ""
  var body: some View {
    VStack {
      TextField("Your feature here...", text: $featureText, axis: .vertical)
        .lineLimit(5...10)
        .padding()
      
      Spacer()
      
      
    }
    .padding()
    .navigationTitle("Request a feature")
    .navigationBarTitleDisplayMode(.inline)
  }
}

#Preview {
  NavigationStack {
    RequestFeatureView()
  }
}
