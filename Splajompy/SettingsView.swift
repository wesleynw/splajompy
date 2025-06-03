import PostHog
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
        NavigationLink(destination: AppIconPickerView()) {
          Label("App Icon", systemImage: "square.grid.2x2")
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

struct AppIconPickerView: View {
    @State private var selectedIcon: String?
    
    init() {
        // Initialize with current app icon
        _selectedIcon = State(initialValue: UIApplication.shared.alternateIconName)
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 20) {
                Image("Image_AppIcon")
                    .resizable()
                    .frame(width: 80, height: 80)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(selectedIcon == nil ? Color.blue : Color.clear, lineWidth: 3)
                    )
                    .onTapGesture {
                        selectedIcon = nil
                        setAppIcon(nil)
                    }
                
                Image("Image_AppIcon 1")
                    .resizable()
                    .frame(width: 80, height: 80)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(selectedIcon == "AppIcon1" ? Color.blue : Color.clear, lineWidth: 3)
                    )
                    .onTapGesture {
                        selectedIcon = "AppIcon1"
                        setAppIcon("AppIcon 1")
                    }
            }
            .padding()
        }
        .navigationTitle("App Icon")
    }
    
    private func setAppIcon(_ iconName: String?) {
        guard UIApplication.shared.alternateIconName != iconName else { return }
        
        UIApplication.shared.setAlternateIconName(iconName) { error in
            if let error = error {
                print("Error setting alternate icon: \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
  SettingsView()
}
