import SwiftUI

struct SettingsView: View {
  @EnvironmentObject private var authManager: AuthManager
  @State var isShowingSignoutConfirm: Bool = false

  var body: some View {
    List {
      Button(action: { isShowingSignoutConfirm = true }) {
        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
      }
      .listStyle(.plain)
      .confirmationDialog("Are you sure you'd like to sign out?", isPresented: $isShowingSignoutConfirm) {
        Button("Sign Out", role: .destructive) { authManager.signOut() }
        Button("Cancel", role: .cancel) {}
      }
    }
    .navigationTitle("Settings")
  }
}

#Preview {
  SettingsView()
}
