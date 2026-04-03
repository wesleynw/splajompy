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
    guard let dataCache = ImagePipeline.shared.configuration.dataCache as? DataCache else { return }
    Task.detached {
      dataCache.flush()
      let size = dataCache.totalSize
      await MainActor.run {
        self.cacheSize = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
      }
    }
  }
}

#Preview {
  List {
    StorageManager()
  }
}
