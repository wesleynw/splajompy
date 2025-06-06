import Kingfisher
import SwiftUI

struct StorageManager: View {
  @State private var cacheSize: String = "Calculating..."

  var body: some View {
    Section {
      HStack {
        Button(action: {
          ImageCache.default.clearMemoryCache()
          ImageCache.default.clearDiskCache {}
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
        case .success(let size):
          cacheSize = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
        case .failure(_):
          cacheSize = "Unknown"
        }
      }
    }
  }
}

#Preview {
  List {
    StorageManager()
  }
}
