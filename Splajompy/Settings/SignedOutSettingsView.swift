import SwiftUI

struct SignedOutSettingsView: View {
  @State private var isShowingDeveloperSettings = false

  var body: some View {
    VStack(spacing: 12) {
      Image(systemName: "person.crop.circle.badge.exclamationmark")
        .font(.system(size: 40))
        .foregroundStyle(.secondary)

      Text("Sign in to access Settings")
        .font(.headline)

      Button("Developer Settings") {
        isShowingDeveloperSettings = true
      }
    }
    .frame(minWidth: 420, idealWidth: 460, minHeight: 260, idealHeight: 280)
    .padding()
    .sheet(isPresented: $isShowingDeveloperSettings) {
      NavigationStack {
        DeveloperSettingsView()
          .toolbar {
            Button("Close") { isShowingDeveloperSettings = false }
          }
      }
    }
  }
}

#Preview {
  SignedOutSettingsView()
}
