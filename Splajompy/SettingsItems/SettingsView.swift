import PostHog
import SwiftUI

struct SettingsView: View {
  @EnvironmentObject private var authManager: AuthManager
  @AppStorage("comment_sort_order") private var commentSortOrder: String = "Newest First"

  var body: some View {
    VStack {
      List {
        NavigationLink(destination: AccountSettingsView()) {
          HStack {
            Label("Account", systemImage: "person.circle")
            Spacer()
            if let user = authManager.getCurrentUser() {
              Text("@\(user.username)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
          }
        }

        NavigationLink(destination: AppearanceSwitcher()) {
          Label("Appearance", systemImage: "circle.lefthalf.filled")
        }

        HStack {
          Label("Comment Sort Order", systemImage: "arrow.up.arrow.down")
          Spacer()
          Picker("Comment Sort Order", selection: $commentSortOrder) {
            Text("Newest First").tag("Newest First")
            Text("Oldest First").tag("Oldest First")
          }
          .pickerStyle(.menu)
          .labelsHidden()
        }

        #if os(iOS)
          NavigationLink(destination: AppIconPickerView()) {
            Label("App Icon", systemImage: "square.grid.2x2")
          }
        #endif

        StorageManager()

        Section {
          NavigationLink(destination: RequestFeatureView()) {
            Label("Support", systemImage: "lifepreserver")
          }
        }

        Section {
          NavigationLink(destination: AboutView()) {
            Label("About", systemImage: "info.circle")
          }
        }

      }
      #if os(macOS)
        .contentMargins(.horizontal, 20, for: .scrollContent)
        .safeAreaPadding(.horizontal, 20)
      #endif
    }
    .navigationTitle("Settings")
  }
}

#Preview {
  let authManager = AuthManager()
  NavigationStack {
    SettingsView()
      .environmentObject(authManager)
  }
}
