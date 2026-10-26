import SwiftUI

struct DeveloperSettingsView: View {
  @Environment(AuthManager.self) private var authManager
  @Environment(\.dismiss) private var dismiss
  @AppStorage(APIService.serverURLKey) private var savedAPIServerURL: String?

  @State private var serverURL: String = APIService.baseUrl
  @State private var isApplyingServer: Bool = false
  @State private var connectionTestURL: URL?
  @State private var connectionResult: Result<Void, Error>?

  private static let defaultServerURL: String =
    normalizeServerURL(APIService.defaultBaseUrl) ?? APIService.defaultBaseUrl

  private var normalizedServerURL: String? {
    Self.normalizeServerURL(serverURL)
  }

  private var canApplyServer: Bool {
    guard let url = normalizedServerURL else { return false }
    return !isApplyingServer
      && url != Self.normalizeServerURL(savedAPIServerURL ?? Self.defaultServerURL)
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
    .disabled(isApplyingServer)
    .pageTitle("Developer")
    .safeAreaInset(edge: .top, spacing: 0) {
      connectionBanner
    }
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        if #available(anyAppleOS 26, *) {
          Button(role: .confirm) { dismiss() }
            .disabled(isApplyingServer)
        } else {
          Button("Done") { dismiss() }
            .disabled(isApplyingServer)
        }
      }
    }
    .onChange(of: normalizedServerURL) {
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
      TextField("URL", text: $serverURL)
        .autocorrectionDisabled()
        #if os(iOS)
          .textInputAutocapitalization(.never)
          .keyboardType(.URL)
        #endif

      Button {
        guard let address = normalizedServerURL else { return }
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
      .disabled(normalizedServerURL == nil || connectionTestURL != nil)

      if normalizedServerURL != Self.defaultServerURL {
        Button("Use Default Server") {
          serverURL = Self.defaultServerURL
        }
      }

      Button("Apply Server") {
        Task { await applyServer() }
      }
      .disabled(!canApplyServer)
    } header: {
      Text("API Server")
    } footer: {
      Text(
        "Include http:// or https:// and an optional port. Applying changes signs you out."
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

  private func applyServer() async {
    guard let url = normalizedServerURL, canApplyServer else { return }
    isApplyingServer = true
    await authManager.signOut(reason: "developer_settings_changed")
    savedAPIServerURL = url == Self.defaultServerURL ? nil : url
    isApplyingServer = false
    dismiss()
  }

  private static func normalizeServerURL(_ value: String) -> String? {
    guard
      var components = URLComponents(
        string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
      let scheme = components.scheme?.lowercased(), ["http", "https"].contains(scheme),
      let host = components.host, !host.isEmpty,
      components.user == nil, components.password == nil,
      components.query == nil, components.fragment == nil,
      components.path.isEmpty || components.path == "/",
      components.port.map({ (1...65535).contains($0) }) ?? true
    else { return nil }
    components.path = ""
    return components.url?.absoluteString
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
