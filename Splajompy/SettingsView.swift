import SwiftUI

struct SettingsView: View {
  @EnvironmentObject private var authManager: AuthManager
  @State var isShowingSignoutConfirm: Bool = false

  let appVersion =
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
  let buildNumber =
    Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""

  var body: some View {
    VStack {
      List {
        Button(action: { isShowingSignoutConfirm = true }) {
          Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
        }
        .listStyle(.plain)
        .confirmationDialog(
          "Are you sure you'd like to sign out?",
          isPresented: $isShowingSignoutConfirm
        ) {
          Button("Sign Out", role: .destructive) { authManager.signOut() }
          Button("Cancel", role: .cancel) {}
        }

      }
      Spacer()

      Text("Version \(appVersion) (\(buildNumber))")
        .font(.footnote)
        .fontWeight(.bold)
        .foregroundColor(.secondary)
        .padding(.bottom)
    }
    .navigationTitle("Settings")
  }
}

#Preview {
  SettingsView()
}
