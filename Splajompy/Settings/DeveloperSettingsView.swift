import SwiftUI

struct DeveloperSettingsView: View {
  @Environment(AuthManager.self) private var authManager
  @Environment(\.dismiss) private var dismiss
  @State private var serverURL = APIService.baseUrl
  @State private var isSaving = false

  private var normalizedURL: String? {
    guard
      let components = URLComponents(
        string: serverURL.trimmingCharacters(in: .whitespacesAndNewlines)),
      let scheme = components.scheme?.lowercased(), ["http", "https"].contains(scheme),
      let host = components.host, !host.isEmpty,
      components.user == nil, components.password == nil,
      components.query == nil, components.fragment == nil,
      components.path.isEmpty || components.path == "/",
      components.port.map({ (1...65535).contains($0) }) ?? true,
      let url = components.url
    else { return nil }
    return url.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
  }

  var body: some View {
    Form {
      Section {
        TextField("API Server URL", text: $serverURL)
          .autocorrectionDisabled()
          #if os(iOS)
            .textInputAutocapitalization(.never)
            .keyboardType(.URL)
          #endif

        Button("Apply and Sign Out") {
          guard let url = normalizedURL else { return }
          isSaving = true
          Task {
            await authManager.changeAPIServer(to: url)
            dismiss()
            isSaving = false
          }
        }
        .disabled(isSaving || normalizedURL == nil || normalizedURL == APIService.baseUrl)

        Button("Use Default Server") {
          serverURL = APIService.defaultBaseUrl
        }
      } footer: {
        Text(
          "Include http:// or https:// and the port. Changing servers signs you out. For local Wi-Fi, use your Mac's .local name."
        )
      }
    }
    .formStyle(.grouped)
    .pageTitle("Developer")
  }
}
