import SwiftUI

struct DeveloperSettingsView: View {
  @Environment(AuthManager.self) private var authManager
  @Environment(\.dismiss) private var dismiss
  @State private var serverURL: String
  @State private var port: String
  @State private var isSaving = false
  @State private var isTestingConnection = false
  @State private var connectionStatus: String?

  init() {
    var components = URLComponents(string: APIService.baseUrl)
    _port = State(initialValue: components?.port.map(String.init) ?? "")
    components?.port = nil
    _serverURL = State(initialValue: components?.string ?? APIService.baseUrl)
  }

  private var normalizedURL: String? {
    guard
      var components = URLComponents(
        string: serverURL.trimmingCharacters(in: .whitespacesAndNewlines)),
      let scheme = components.scheme?.lowercased(), ["http", "https"].contains(scheme),
      let host = components.host, !host.isEmpty,
      components.user == nil, components.password == nil, components.port == nil,
      components.query == nil, components.fragment == nil,
      components.path.isEmpty || components.path == "/"
    else { return nil }
    let port = port.trimmingCharacters(in: .whitespacesAndNewlines)
    if !port.isEmpty {
      guard let number = Int(port), (1...65535).contains(number) else { return nil }
      components.port = number
    }
    components.path = ""
    return components.url?.absoluteString
  }

  var body: some View {
    Form {
      Section("API Server") {
        TextField("URL", text: $serverURL)
          .autocorrectionDisabled()
          #if os(iOS)
            .textInputAutocapitalization(.never)
            .keyboardType(.URL)
          #endif

        TextField("Port", text: $port)
          #if os(iOS)
            .keyboardType(.numberPad)
          #endif

        Button {
          guard let address = normalizedURL,
            let url = URL(string: address)?.appendingPathComponent("health")
          else { return }
          isTestingConnection = true
          connectionStatus = nil
          Task {
            connectionStatus = await testConnection(to: url)
            isTestingConnection = false
          }
        } label: {
          Text("Test Connection")
            .opacity(isTestingConnection ? 0 : 1)
            .overlay {
              if isTestingConnection { ProgressView() }
            }
        }
        .disabled(normalizedURL == nil)

        if let connectionStatus {
          Text(connectionStatus)
            .foregroundStyle(.secondary)
        }

        Button("Apply and Sign Out") {
          guard let url = normalizedURL else { return }
          isSaving = true
          Task {
            await authManager.changeAPIServer(to: url)
            dismiss()
            isSaving = false
          }
        }
        .disabled(normalizedURL == nil || normalizedURL == APIService.baseUrl)

        Button("Use Default Server") {
          var components = URLComponents(string: APIService.defaultBaseUrl)
          port = components?.port.map(String.init) ?? ""
          components?.port = nil
          serverURL = components?.string ?? APIService.defaultBaseUrl
        }
      }
      .disabled(isSaving || isTestingConnection)
    }
    .formStyle(.grouped)
    .pageTitle("Developer")
    .onChange(of: normalizedURL) { connectionStatus = nil }
  }

  private func testConnection(to url: URL) async -> String {
    var request = URLRequest(
      url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 5)
    request.httpShouldHandleCookies = false
    do {
      let (_, response) = try await URLSession.shared.data(for: request)
      guard let response = response as? HTTPURLResponse else { return "Invalid server response." }
      return (200...299).contains(response.statusCode)
        ? "Connected." : "Server returned HTTP \(response.statusCode)."
    } catch {
      return error.localizedDescription
    }
  }
}
