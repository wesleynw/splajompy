import SwiftUI

struct OnboardingView: View {
  let onComplete: () -> Void

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 32) {
          VStack(spacing: 16) {
            Text(
              "From now on, rather than seeing all posts on Splajompy, you will only see posts from"
            ) + Text(" friends ").foregroundStyle(.green) + Text("and")
              + Text(" mutuals").foregroundStyle(.purple) + Text(".")

            Text(
              "If you're curious why you're seeing someone's posts, you can see how you may know them in their profile."
            )
          }
          .multilineTextAlignment(.center)
        }
        .padding()
      }
      .navigationTitle("What's New")

      //      VStack {
      //        Spacer()
      //
      //        Button(action: onComplete) {
      //          Text("Get Started")
      //            .font(.headline)
      //            .frame(maxWidth: .infinity)
      //            .padding(.vertical, 12)
      //        }
      //        .clipShape(RoundedRectangle(cornerRadius: 12))
      //        .buttonStyle(.borderedProminent)
      //        .padding()
      //      }

      VStack {
        Button(action: onComplete) {
          Text("Sure, why not")
            .padding(.vertical, 5)
            .padding(.horizontal)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
      }
      .padding()

    }
  }
}

#Preview {
  OnboardingView {
    print("done")
  }
}
