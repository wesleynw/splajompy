import Foundation
import PostHog

final class KeychainHelper: @unchecked Sendable {

  static let standard = KeychainHelper()
  private init() {}

  func save(_ data: Data, service: String, account: String) {
    let query =
      [
        kSecValueData: data,
        kSecAttrService: service,
        kSecAttrAccount: account,
        kSecClass: kSecClassGenericPassword,
        kSecUseDataProtectionKeychain: true,
      ] as CFDictionary

    let status = SecItemAdd(query, nil)

    if status == errSecDuplicateItem {
      let findQuery =
        [
          kSecAttrService: service,
          kSecAttrAccount: account,
          kSecClass: kSecClassGenericPassword,
          kSecUseDataProtectionKeychain: true,
        ] as CFDictionary

      let attributesToUpdate = [kSecValueData: data] as CFDictionary
      let updateStatus = SecItemUpdate(findQuery, attributesToUpdate)

      if updateStatus != errSecSuccess {
        PostHogSDK.shared.capture(
          "keychain_write_failed",
          properties: ["op": "update", "service": service, "status": updateStatus]
        )
      }
    } else if status != errSecSuccess {
      PostHogSDK.shared.capture(
        "keychain_write_failed",
        properties: ["op": "add", "service": service, "status": status]
      )
    }
  }

  func readWithStatus(service: String, account: String) -> (data: Data?, status: OSStatus) {
    let query =
      [
        kSecAttrService: service,
        kSecAttrAccount: account,
        kSecClass: kSecClassGenericPassword,
        kSecReturnData: true,
        kSecUseDataProtectionKeychain: true,
      ] as CFDictionary

    var result: AnyObject?
    let status = SecItemCopyMatching(query, &result)

    return (result as? Data, status)
  }

  func delete(service: String, account: String) {
    let query =
      [
        kSecAttrService: service,
        kSecAttrAccount: account,
        kSecClass: kSecClassGenericPassword,
        kSecUseDataProtectionKeychain: true,
      ] as CFDictionary

    SecItemDelete(query)
  }
}
