import Kingfisher
import PostHog
import SwiftUI

struct SettingsView: View {
  @EnvironmentObject private var authManager: AuthManager
  @State var isShowingSignoutConfirm: Bool = false
  @AppStorage("mindlessMode") private var mindlessMode: Bool = false

  let appVersion =
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
  let buildNumber =
    Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""

  var body: some View {
    VStack {
      List {
        NavigationLink(destination: AppearanceSwitcher()) {
          Label("Appearance", systemImage: "circle.lefthalf.filled")
        }

        NavigationLink(destination: AppIconPickerView()) {
          Label("App Icon", systemImage: "square.grid.2x2")
        }

        Toggle(isOn: $mindlessMode) {
          Label("Mindless Mode", systemImage: "infinity")
        }

        Button(action: { isShowingSignoutConfirm = true }) {
          Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
        }
        .listStyle(.plain)
        .confirmationDialog(
          "Are you sure you'd like to sign out?",
          isPresented: $isShowingSignoutConfirm
        ) {
          Button("Sign Out", role: .destructive) {
            PostHogSDK.shared.reset()
            authManager.signOut()
          }
          Button("Cancel", role: .cancel) {}
        }

        StorageManager()

        Section {
          HStack {
            Text("Version")
            Spacer()
            Text("\(appVersion) (Build \(buildNumber))")
              .font(.footnote)
              .fontWeight(.bold)
              .foregroundColor(.secondary)
          }
        }
      }
    }
    .navigationTitle("Settings")
  }
}

#Preview {
  NavigationStack {
    SettingsView()
  }
}
