import SwiftUI

struct WrappedIntroView: View {
  @StateObject private var viewModel = WrappedViewModel()
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      VStack(spacing: 20) {
        Text("Welcome to your 2025 Splajompy Wrapped!")
          .fontWeight(.bold)
          .font(.title2)
          .multilineTextAlignment(.center)
          .padding()

        ProgressView()

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
        if case .loaded(let data) = viewModel.state {
          NavigationLink(
            destination: ActivityOverview(data: data)
          ) {
            Text("Start")
              .padding(3)
              .fontWeight(.black)
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.borderedProminent)
        } else {
          Button {

          } label: {
            Text("Start")
              .padding(3)
              .fontWeight(.black)
              .frame(maxWidth: .infinity)
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
    }
  }
}

#Preview {
  WrappedIntroView()
}
