import SwiftUI

struct DeveloperSettingsView: View {
  @Environment(AuthManager.self) private var authManager
  @Environment(\.dismiss) private var dismiss
  @AppStorage(APIService.serverURLKey) private var savedAPIServerURL: String?

  @State private var settings: DeveloperSettingsManager = .current
  @State private var isSaving: Bool = false
  @State private var isSignOutConfirmationPresenting: Bool = false
  @State private var connectionTestURL: URL?
  @State private var connectionResult: Result<Void, Error>?

  private var changedSettings: [DeveloperSettingsManager.Setting] {
    settings.validated?.changedSettings(from: .current) ?? []
  }

  private var canSave: Bool {
    !isSaving && settings.validated != nil && !changedSettings.isEmpty
  }

  private var changedSettingsRequiringSignOut: [DeveloperSettingsManager.Setting] {
    changedSettings.filter {
      DeveloperSettingsManager.settingsRequiringSignOut.contains($0)
    }
  }

  private var connectionStatus: (message: String, color: Color, icon: String)? {
    guard let connectionResult else { return nil }
    switch connectionResult {
    case .success:
      return ("Connection successful", .green, "checkmark.circle.fill")
    case .failure(let error):
      let message = error.localizedDescription.trimmingCharacters(
        in: .whitespacesAndNewlines.union(.punctuationCharacters)
      )
      return (message, .red, "exclamationmark.circle.fill")
    }
  }

  var body: some View {
    Form {
      settingsSections
    }
    .formStyle(.grouped)
    .disabled(isSaving)
    .pageTitle("Developer")
    .safeAreaInset(edge: .top, spacing: 0) {
      connectionBanner
    }
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Close") { dismiss() }
          .disabled(isSaving)
      }
      ToolbarItem(placement: .confirmationAction) {
        if #available(anyAppleOS 26, *) {
          Button(role: .confirm) {
            if changedSettingsRequiringSignOut.isEmpty {
              saveSettings()
            } else {
              isSignOutConfirmationPresenting = true
            }
          }
          .disabled(!canSave)
        } else {
          Button("Save") {
            if changedSettingsRequiringSignOut.isEmpty {
              saveSettings()
            } else {
              isSignOutConfirmationPresenting = true
            }
          }
          .disabled(!canSave)
        }
      }
    }
    .alert("Save Changes?", isPresented: $isSignOutConfirmationPresenting) {
      Button("Cancel", role: .cancel) {}
      Button("Save and Sign Out", role: .destructive) { saveSettings() }
    } message: {
      Text(
        "Changing \(changedSettingsRequiringSignOut.map(\.rawValue).formatted(.list(type: .and))) will sign you out"
      )
    }
    .onChange(of: settings.validated?.apiServerURL) {
      connectionTestURL = nil
      connectionResult = nil
    }
    .task(id: connectionTestURL) {
      guard let url = connectionTestURL else { return }
      let result = await testConnection(to: url)
      guard !Task.isCancelled, connectionTestURL == url else { return }
      connectionResult = result
      connectionTestURL = nil
    }
  }

  @ViewBuilder
  private var settingsSections: some View {
    Section {
      TextField("URL", text: $settings.apiServerURL)
        .autocorrectionDisabled()
        #if os(iOS)
          .textInputAutocapitalization(.never)
          .keyboardType(.URL)
        #endif

      Button {
        guard let address = settings.validated?.apiServerURL else { return }
        connectionResult = nil
        connectionTestURL = URL(string: address)?.appendingPathComponent(
          "health"
        )
      } label: {
        HStack {
          Text("Test Connection")
          if connectionTestURL != nil {
            ProgressView()
              .controlSize(.small)
          } else if let status = connectionStatus {
            Image(systemName: status.icon)
              .foregroundStyle(status.color)
          }
        }
      }
      .disabled(settings.validated == nil || connectionTestURL != nil)

      if settings.validated?.apiServerURL
        != DeveloperSettingsManager.defaults.apiServerURL
      {
        Button("Use Default Server") {
          settings.apiServerURL = DeveloperSettingsManager.defaults.apiServerURL
        }
      }
    } header: {
      Text("API Server")
    } footer: {
      Text(
        "Include http:// or https:// and an optional port. Saving a changed URL signs you out."
      )
    }
  }

  @ViewBuilder
  private var connectionBanner: some View {
    if let status = connectionStatus {
      Label(status.message, systemImage: status.icon)
        .font(.subheadline)
        .foregroundStyle(status.color)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(status.color.opacity(0.12))
    }
  }

  private func saveSettings() {
    guard let settings = settings.validated else { return }
    let requiresSignOut = !changedSettingsRequiringSignOut.isEmpty
    isSaving = true
    Task {
      if requiresSignOut {
        await authManager.signOut(reason: "developer_settings_changed")
      }
      if settings.apiServerURL == DeveloperSettingsManager.defaults.apiServerURL {
        savedAPIServerURL = nil
      } else {
        savedAPIServerURL = settings.apiServerURL
      }
      isSaving = false
      dismiss()
    }
  }

  private func testConnection(to url: URL) async -> Result<Void, Error> {
    var request = URLRequest(
      url: url,
      cachePolicy: .reloadIgnoringLocalCacheData,
      timeoutInterval: 5
    )
    request.httpShouldHandleCookies = false
    do {
      let (_, response) = try await URLSession.shared.data(for: request)
      guard let response = response as? HTTPURLResponse else {
        throw URLError(.badServerResponse)
      }
      guard (200...299).contains(response.statusCode) else {
        throw APIErrorMessage(
          message: "Server returned HTTP \(response.statusCode)"
        )
      }
      return .success(())
    } catch {
      return .failure(error)
    }
  }
}
