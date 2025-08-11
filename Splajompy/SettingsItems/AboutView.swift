import SwiftUI

struct AboutView: View {
  let appVersion =
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
  let buildNumber =
    Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""

  var body: some View {
    VStack {
      List {
        Section {
          VStack(alignment: .center, spacing: 12) {
            Image("Logo")
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(width: 80, height: 80)
            
            Text("Splajompy")
              .font(.title2)
              .fontWeight(.semibold)
            
            Text("A free and open-source social media platform built with privacy and community in mind.")
              .font(.subheadline)
              .foregroundColor(.secondary)
              .multilineTextAlignment(.center)
              .padding(.horizontal)
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 20)
        }
        
        Section {
          Link(destination: URL(string: "https://github.com/wesleynw/splajompy")!) {
            HStack {
              Label("Source Code", systemImage: "chevron.left.forwardslash.chevron.right")
              Spacer()
              Image(systemName: "arrow.up.right.square")
                .foregroundColor(.secondary)
                .font(.caption)
            }
          }
        } footer: {
          Text("Splajompy is open-source software. View the code, contribute, or report issues on GitHub.")
        }
        
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
      #if os(macOS)
        .contentMargins(.horizontal, 20, for: .scrollContent)
        .safeAreaPadding(.horizontal, 20)
      #endif
    }
    .navigationTitle("About")
    #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
    #endif
  }
}

#Preview {
  NavigationStack {
    AboutView()
  }
}