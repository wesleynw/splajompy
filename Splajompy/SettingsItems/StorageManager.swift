import Kingfisher
import Nuke
import SwiftUI

struct StorageManager: View {
  @State private var cacheSize: String = "Calculating..."

  var body: some View {
    Section {
      HStack {
        Button(action: {
          // TODO: remove when users' KF caches clear out, should take like one or two weeks
          ImageCache.default.clearMemoryCache()
          ImageCache.default.clearDiskCache {}

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
    ImageCache.default.calculateDiskStorageSize { result in
      DispatchQueue.main.async {
        switch result {
        case .success(let kingfisherSize):
          let nukeSize = self.getNukeCacheSize()
          let totalSize = Int64(kingfisherSize) + Int64(nukeSize)
          self.cacheSize = ByteCountFormatter.string(
            fromByteCount: totalSize,
            countStyle: .file
          )
        case .failure(_):
          self.cacheSize = "Unknown"
        }
      }
    }
  }

  private func getNukeCacheSize() -> Int {
    return ImageCache.shared.totalCost
  }
}

#Preview {
  List {
    StorageManager()
  }
}
