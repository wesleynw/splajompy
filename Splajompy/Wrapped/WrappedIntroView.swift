import SwiftUI

enum WrappedPage {
  case intro
  case activity
  case weeklyActivity
  case lengthComparison
  case mostLikedPost
  case controversialPoll
  case slice
  case favoriteUsers
  case totalWordCount
}

@available(macOS, unavailable)
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

        if case .loaded(let data) = viewModel.state {
          Text("Data last generated \(data.generatedUtc.ISO8601Format())")
        }

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
      .frame(maxWidth: .infinity)
      .padding()
      .overlay(alignment: .bottom) {
        if case .loaded = viewModel.state {
          Button {
            path.append(.weeklyActivity)
          } label: {
            Text("Start")
              .frame(maxWidth: .infinity)
              .fontWeight(.bold)
          }
          .padding()
          .controlSize(.large)
          .modify {
            if #available(iOS 26, *) {
              $0.buttonStyle(.glassProminent)
            } else {
              $0.buttonStyle(.borderedProminent)
            }
          }

        } else {
          Button {
            path.append(.weeklyActivity)
          } label: {
            Text("Start")
              .frame(maxWidth: .infinity)
              .fontWeight(.bold)
          }
          .controlSize(.large)
          .modify {
            if #available(iOS 26, *) {
              $0.buttonStyle(.glassProminent)
            } else {
              $0.buttonStyle(.borderedProminent)
            }
          }
          .disabled(true)
          .padding()
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
    }
  }

  @ViewBuilder
  private func destinationView(for page: WrappedPage) -> some View {
    switch viewModel.state {
    case .loaded(let data):
      switch page {
      case .weeklyActivity:
        WeeklyActivityView(data: data, onContinue: { path.append(.activity) })
      case .activity:
        YearlyActivityView(
          data: data,
          onContinue: { path.append(.mostLikedPost) }
        )
        .closeToolbar(onDismiss: dismiss.callAsFunction)
      case .slice:
        UserProportionRing(data: data)
          .closeToolbar(onDismiss: dismiss.callAsFunction)
      case .lengthComparison:
        LengthComparisonView(
          data: data,
          onContinue: { path.append(.totalWordCount) }
        )
        .closeToolbar(onDismiss: dismiss.callAsFunction)
      case .totalWordCount:
        TotalWordCountView(
          data: data,
          onContinue: { path.append(.favoriteUsers) }
        )
        .closeToolbar(onDismiss: dismiss.callAsFunction)
      case .mostLikedPost:
        MostLikedPostView(
          data: data,
          onContinue: { path.append(.controversialPoll) }
        )
        .closeToolbar(onDismiss: dismiss.callAsFunction)
      case .controversialPoll:
        ControversialPollView(
          data: data,
          onContinue: { path.append(.lengthComparison) }
        )
      case .favoriteUsers:
        FavoriteUsersView(data: data, onContinue: { path.append(.slice) })
          .closeToolbar(onDismiss: dismiss.callAsFunction)
      case .intro:
        WrappedIntroView()
      }
    default:
      ProgressView()
    }
  }
}

@available(macOS, unavailable)
struct CloseToolbarModifier: ViewModifier {
  let onDismiss: () -> Void

  func body(content: Content) -> some View {
    content.toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        if #available(iOS 26.0, *) {
          Button(role: .close, action: onDismiss)
        } else {
          Button(action: onDismiss) {
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
  @available(macOS, unavailable)
  func closeToolbar(onDismiss: @escaping () -> Void) -> some View {
    modifier(CloseToolbarModifier(onDismiss: onDismiss))
  }
}
