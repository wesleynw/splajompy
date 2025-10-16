import SwiftUI

struct StatRow: View {
  let label: String
  let value: Int

  var body: some View {
    HStack {
      Text(label)
        .foregroundColor(.primary)
      Spacer()
      Text("\(value)")
        .fontWeight(.semibold)
        .foregroundColor(.secondary)
    }
  }
}

struct StatisticsView: View {
  @State private var stats: AppStats?
  @State private var isLoading = false
  @State private var errorMessage: String?

  private let profileService: ProfileServiceProtocol

  init(profileService: ProfileServiceProtocol = ProfileService()) {
    self.profileService = profileService
  }

  var body: some View {
    Group {
      if stats == nil && errorMessage == nil {
        VStack {
          Spacer()
          ProgressView()
            .scaleEffect(1.5)
            .padding()
          Spacer()
        }
      } else if let errorMessage = errorMessage, stats == nil {
        VStack {
          Spacer()
          Text("Unable to load statistics")
            .font(.headline)
            .padding(.bottom, 4)
          Text(errorMessage)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
          Button {
            Task { await loadStats() }
          } label: {
            HStack {
              if isLoading {
                ProgressView()
                  .scaleEffect(0.8)
              } else {
                Image(systemName: "arrow.clockwise")
              }
              Text("Retry")
            }
          }
          .padding()
          .buttonStyle(.bordered)
          .disabled(isLoading)
          Spacer()
        }
      } else if let stats = stats {
        List {
          StatRow(label: "Posts", value: stats.totalPosts)
          StatRow(label: "Comments", value: stats.totalComments)
          StatRow(label: "Likes", value: stats.totalLikes)
          StatRow(label: "Follows", value: stats.totalFollows)
          StatRow(label: "Splajompians", value: stats.totalUsers)
          StatRow(label: "Notifications", value: stats.totalNotifications)
        }
        .refreshable {
          await loadStats()
        }
      }
    }
    .navigationTitle("Statistics")
    #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
    #endif
    .task {
      Task {
        await loadStats()
      }
    }
  }

  private func loadStats() async {
    isLoading = true
    errorMessage = nil

    let result = await profileService.getAppStats()

    switch result {
    case .success(let appStats):
      stats = appStats
      errorMessage = nil
    case .error(let error):
      if stats == nil {
        errorMessage = error.localizedDescription
      }
    }

    isLoading = false
  }
}

#Preview {
  NavigationStack {
    StatisticsView(profileService: MockProfileService())
  }
}
