import PostHog
import SwiftUI

struct SplashScreenView: View {
  @Environment(AuthManager.self) private var authManager
  @State private var isLoginViewPresenting: Bool = false
  @State private var isRegisterViewPresenting: Bool = false
  @State private var isDeveloperSettingsUnlocked = false
  @State private var isShowingDeveloperSettings = false

  var body: some View {
    VStack {
      Image("snail-small")
        .resizable()
        .scaledToFit()
        .frame(height: 160)
        .onTapGesture(count: 5) { isDeveloperSettingsUnlocked = true }
        .padding(.top, 150)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .overlay(alignment: .bottom) {
      HStack(spacing: 16) {
        Button {
          isLoginViewPresenting = true
        } label: {
          Text("Log In")
            .font(SJFont.title3)
            .frame(maxWidth: .infinity)
        }
        .modify {
          if #available(iOS 26, macOS 26, *) {
            $0.buttonStyle(.glass)
          } else {
            $0.buttonStyle(.bordered)
          }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.extraLarge)
        .sensoryFeedback(.impact, trigger: isLoginViewPresenting)

        Button {
          isRegisterViewPresenting = true
        } label: {
          Text("Sign Up")
            .font(SJFont.title3)
            .frame(maxWidth: .infinity)
        }
        .modify {
          if #available(iOS 26, macOS 26, *) {
            $0.buttonStyle(.glassProminent)
          } else {
            $0.buttonStyle(.borderedProminent)
          }
        }
        .controlSize(.extraLarge)
        .sensoryFeedback(.impact, trigger: isRegisterViewPresenting)
      }
      .padding()
    }
    .overlay(alignment: .topTrailing) {
      if isDeveloperSettingsUnlocked {
        Button {
          isShowingDeveloperSettings = true
        } label: {
          Label("Developer Settings", systemImage: "hammer")
            .labelStyle(.iconOnly)
        }
        .padding()
      }
    }
    .sheet(isPresented: $isShowingDeveloperSettings) {
      NavigationStack {
        DeveloperSettingsView()
          .toolbar {
            ToolbarItem(placement: .cancellationAction) {
              Button("Close") { isShowingDeveloperSettings = false }
            }
          }
      }
    }
    #if os(iOS)
      .fullScreenCover(isPresented: $isLoginViewPresenting) {
        LoginView()
        .postHogScreenView()
      }
      .fullScreenCover(isPresented: $isRegisterViewPresenting) {
        RegisterView()
        .postHogScreenView()
      }
    #else
      .sheet(isPresented: $isLoginViewPresenting) {
        LoginView()
        .postHogScreenView()
      }
      .sheet(isPresented: $isRegisterViewPresenting) {
        RegisterView()
        .postHogScreenView()
      }
    #endif
  }
}

#Preview {
  SplashScreenView()
    .environment(AuthManager())
}
