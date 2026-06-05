import SwiftUI

struct PushNotificationsOnboardingView: View {
  var onComplete: () -> Void

  var body: some View {
    VStack {
      VStack {
        VStack(spacing: 6) {
          Text("Listen to us.")
            .font(.title)
            .fontWeight(.bold)

          Text(
            "Let Splajompy bother you with push notications."
          )
          .foregroundStyle(.secondary)
          .padding()
        }
        .padding()

        PushNotificationSettingsView()
          .scrollContentBackground(.hidden)
      }
    }
    .multilineTextAlignment(.center)
    .safeAreaInset(edge: .bottom) {
      Button {
        onComplete()
      } label: {
        Text("Save")
          .fontWeight(.semibold)
          .frame(maxWidth: .infinity)
      }
      .controlSize(.large)
      .modify {
        if #available(iOS 26, *) {
          $0.buttonStyle(.glassProminent)
        } else {
          $0.buttonStyle(.borderedProminent)
        }
      }
      .padding()
    }
  }
}

#Preview {
  NavigationStack {
    Color.clear
      .sheet(isPresented: .constant(true)) {
        PushNotificationsOnboardingView(
          onComplete: {}
        )
      }
  }
}
