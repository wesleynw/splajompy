import SwiftUI

enum WrappedPage {
  case intro
  case activity
  case lengthComparison
  case mostLikedPost
  case slice
  case favoriteUsers
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
          VStack {
            Text("Error: \(error)")
              .foregroundStyle(.red)
            Button("Retry") {
              Task {
                await viewModel.load()
              }
            }
            .buttonStyle(.bordered)
          }
          .transition(.opacity)
        }
      }
      .animation(.default, value: viewModel.state.isLoading)
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
      .navigationDestination(for: WrappedPage.self) { selection in
        destinationView(for: selection)
      }
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
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
        .closeToolbar()
      case .slice:
        UserProportionRing(data: data)
          .closeToolbar()
      case .lengthComparison:
        LengthComparisonView(
          data: data,
          onContinue: { path.append(.favoriteUsers) }
        )
        .closeToolbar()
      case .mostLikedPost:
        MostLikedPostView(
          data: data,
          onContinue: { path.append(.lengthComparison) }
        )
        .closeToolbar()
      case .favoriteUsers:
        FavoriteUsersView(data: data, onContinue: { path.append(.slice) })
          .closeToolbar()
      case .intro:
        WrappedIntroView()
      }
    default:
      ProgressView()
    }
  }
}

struct CloseToolbarModifier: ViewModifier {
  @Environment(\.dismiss) private var dismiss

  func body(content: Content) -> some View {
    content.toolbar {
      ToolbarItem(placement: .topBarTrailing) {
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
  }
}

extension View {
  func closeToolbar() -> some View {
    modifier(CloseToolbarModifier())
  }
}
