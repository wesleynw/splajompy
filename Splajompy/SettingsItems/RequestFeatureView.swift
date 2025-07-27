import SwiftUI

struct RequestFeatureView: View {
  private let profileService: ProfileServiceProtocol

  init(profileService: ProfileServiceProtocol = ProfileService()) {
    self.profileService = profileService
  }

  @State private var featureText: String = ""
  @State private var isLoading: Bool = false
  @State private var showAlert: Bool = false
  @State private var hadSuccess: Bool = false

  @Environment(\.dismiss) private var dismiss

  @FocusState private var isFocused: Bool

  var body: some View {
    VStack {
      TextField("Your feature here...", text: $featureText, axis: .vertical)
        .lineLimit(5...10)
        .padding()
        .focused($isFocused)

      Spacer()

    }
    .padding()
    .navigationTitle("Request a feature")
    #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
    #endif
    .toolbar {
      ToolbarItem(
        placement: {
          #if os(iOS)
            .topBarTrailing
          #else
            .primaryAction
          #endif
        }()
      ) {
        Button {
          sendRequestedFeature()
        } label: {
          ProgressView()
            .opacity(isLoading ? 1 : 0)
          Text("Send")
            .fontWeight(.bold)
        }
        .disabled(
          featureText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || isLoading
        )
      }
    }
    .alert(hadSuccess ? "Thanks!" : "Error", isPresented: $showAlert) {
      Button("OK", role: .cancel) {
        showAlert.toggle()

        if hadSuccess {
          dismiss()
        }
      }
    } message: {
      hadSuccess
        ? Text("Your request will be send to the developer.")
        : Text("Try again.")
    }
    .onAppear {
      isFocused = true
    }
  }

  private func sendRequestedFeature() {
    isLoading = true

    Task { @MainActor in
      let result = await profileService.requestFeature(text: featureText)

      switch result {
      case .error:
        hadSuccess = false
      case .success:
        hadSuccess = true
      }

      isLoading = false
      showAlert.toggle()
    }

  }
}

#Preview {
  NavigationStack {
    RequestFeatureView(profileService: MockProfileService())
  }
}
