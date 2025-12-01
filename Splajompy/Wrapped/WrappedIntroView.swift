import SwiftUI

enum WrappedPage {
  case intro
  case activity
  case lengthComparison
  case mostLikedPost
  case slice
}

struct WrappedIntroView: View {
  @State private var path: [WrappedPage] = []
  @StateObject private var viewModel: WrappedViewModel = WrappedViewModel()
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack(path: $path) {
      VStack {
        Text("Welcome to your 2025 Splajompy Wrapped!")
          .fontWeight(.bold)
          .font(.title2)
          .fontDesign(.rounded)
          .multilineTextAlignment(.center)
          .padding()

        ProgressView()
          .opacity(viewModel.state.isLoading ? 1 : 0)

        if case .failed(let error) = viewModel.state {
          VStack(spacing: 12) {
            Text("Failed to load wrapped data")
              .foregroundStyle(.red)
            Text(error)
              .font(.caption)
              .foregroundStyle(.secondary)
            Button("Retry") {
              Task {
                await viewModel.load()
              }
            }
            .buttonStyle(.bordered)
          }
        }
      }
      .task {
        await viewModel.load()
      }
      .frame(maxHeight: .infinity)
      .safeAreaInset(edge: .bottom) {
        if case .loaded = viewModel.state {
          Button("Start") {
            path.append(.activity)
          }
          .buttonStyle(.borderedProminent)
        } else {
          Button("Start") {
          }
          .buttonStyle(.borderedProminent)
          .disabled(true)
        }
      }
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          if #available(iOS 26.0, *) {
            Button(role: .close, action: { dismiss() })
          } else {
            Button {
              dismiss()
            } label: {
              Image(systemName: "xmark.circle.fill")
                .opacity(0.8)
            }
            .buttonStyle(.plain)
          }
        }
      }
      .padding()
      .navigationDestination(for: WrappedPage.self) { selection in
        destinationView(for: selection)
      }
    }
  }

  @ViewBuilder
  private func destinationView(for page: WrappedPage) -> some View {
    switch viewModel.state {
    case .loaded(let data):
      switch page {
      case .activity:
        ActivityOverview(
          data: data,
          onContinue: { path.append(.mostLikedPost) }
        )
      case .slice:
        UserProportionRing(data: data)
      case .lengthComparison:
        LengthComparisonView(data: data, onContinue: { path.append(.slice) })
      case .mostLikedPost:
        MostLikedPostView(
          data: data,
          onContinue: { path.append(.lengthComparison) }
        )
      case .intro:
        WrappedIntroView()
      }
    default:
      ProgressView()
    }
  }
}
