import Nuke
import SwiftUI

struct StorageManager: View {
  @State private var cacheSize: String = "Calculating..."

  var body: some View {
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
  List {
    StorageManager()
  }
}
