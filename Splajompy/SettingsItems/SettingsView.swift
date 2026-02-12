import PostHog
import SwiftUI

struct SettingsView: View {
  @Environment(AuthManager.self) private var authManager
  @State private var isShowingWrappedView: Bool = false
  @State private var wrappedViewModel: WrappedViewModel =
    WrappedViewModel()

  var body: some View {
    VStack {
      List {
        if PostHogSDK.shared.isFeatureEnabled("rejomp-section-in-settings"),
          case .loaded(true) = wrappedViewModel.eligibility
        {
          Section {
            Button {
              isShowingWrappedView = true
            } label: {
              Label(
                "Rejomp 2025",
                systemImage:
                  "clock.arrow.trianglehead.counterclockwise.rotate.90"
              )
              .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)
            .frame(maxWidth: .infinity, alignment: .leading)
          }
          .transition(.slide)
        }

        NavigationLink(value: SettingsRoute.account) {
          Label("Account", systemImage: "person.circle")
        }

        NavigationLink(value: SettingsRoute.appearance) {
          Label("Appearance", systemImage: "circle.lefthalf.filled")
        }

        #if os(iOS)
          NavigationLink(value: SettingsRoute.appIcon) {
            Label("App Icon", systemImage: "square.grid.2x2")
          }
        #endif

        if PostHogSDK.shared.isFeatureEnabled("secret-tab") {
          NavigationLink(value: SettingsRoute.secretPage) {
            Label("Secret Page", systemImage: "fossil.shell")
          }
        }

        Section {
          NavigationLink(value: SettingsRoute.support) {
            Label("Support", systemImage: "lifepreserver")
          }
        } footer: {
          Text(
            "This is your place to request a feature, ask for help, or just leave a note about what you think about Splajompy!"
          )
        }

        Section {
          NavigationLink(value: SettingsRoute.about) {
            Label("About", systemImage: "info.circle")
          }
        }
      }
      .animation(.default, value: wrappedViewModel.eligibility)
    }
    .navigationTitle("Settings")
    #if os(iOS)
      .fullScreenCover(isPresented: $isShowingWrappedView) {
        WrappedIntroView()
      }
      .task {
        await wrappedViewModel.loadEligibility()
      }
    #endif
  }
}

#Preview {
  let authManager = AuthManager()
  NavigationStack {
    SettingsView()
      .environment(authManager)
  }
}
