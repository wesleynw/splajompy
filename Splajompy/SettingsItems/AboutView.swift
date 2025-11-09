import Nuke
import PostHog
import SwiftUI

struct AboutView: View {
  let appVersion =
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
  let buildNumber =
    Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""

  @State private var cacheSize: String = "Calculating..."

  var body: some View {
    VStack {
      List {
        Section {
          VStack(alignment: .center) {
            Image("Logo")
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(width: 80, height: 80)

            Text("Splajompy")
              .font(.title2)
              .fontWeight(.semibold)

            Text("Splajompy is free and open-source.")
              .font(.subheadline)
              .foregroundColor(.secondary)
              .multilineTextAlignment(.center)
              .padding(.horizontal)
          }
          .padding()
          .frame(maxWidth: .infinity)
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

        Section {
          Link(
            destination: URL(string: "https://github.com/wesleynw/splajompy")!
          ) {
            HStack {
              Label(
                "Source Code",
                systemImage: "chevron.left.forwardslash.chevron.right"
              )
            }
          }
        }

        Section {
          Link(destination: URL(string: "https://splajompy.com/privacy")!) {
            HStack {
              Label("Privacy Policy", systemImage: "lock.shield")
              Spacer()
            }
          }
          Link(destination: URL(string: "https://splajompy.com/tos")!) {
            HStack {
              Label("Terms of Service", systemImage: "doc.text")
              Spacer()
            }
          }
        }

        if PostHogSDK.shared.isFeatureEnabled("statistics-page") {
          Section {
            NavigationLink(destination: StatisticsView()) {
              Label("Statistics", systemImage: "chart.xyaxis.line")
            }
          }
        }

        Section {
          HStack {
            Button(action: {
              ImageCache.shared.removeAll()
              if let dataCache = ImagePipeline.shared.configuration.dataCache {
                dataCache.removeAll()
              }

              updateCacheSize()
            }) {
              Text("Clear Cache")
            }

            Spacer()

            Text(cacheSize)
              .foregroundStyle(.secondary)
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
    .task {
      updateCacheSize()
    }
  }

  private func updateCacheSize() {
    let cache = try? DataCache(name: "media-cache")
    if let cache = cache {
      self.cacheSize = ByteCountFormatter.string(
        fromByteCount: Int64(cache.totalSize),
        countStyle: .file
      )
    }
  }
}

#Preview {
  NavigationStack {
    AboutView()
  }
}
