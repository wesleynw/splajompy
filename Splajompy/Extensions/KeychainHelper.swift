import Foundation
import PostHog

final class KeychainHelper: @unchecked Sendable {

  static let standard = KeychainHelper()
  private init() {}

  @discardableResult
  func save(_ data: Data, service: String, account: String) -> Bool {
    let query =
      [
        kSecValueData: data,
        kSecAttrService: service,
        kSecAttrAccount: account,
        kSecClass: kSecClassGenericPassword,
        kSecUseDataProtectionKeychain: true,
        kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
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

      let attributesToUpdate =
        [
          kSecValueData: data,
          kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ] as CFDictionary
      let updateStatus = SecItemUpdate(findQuery, attributesToUpdate)

      if updateStatus != errSecSuccess {
        PostHogSDK.shared.capture(
          "keychain_write_failed",
          properties: ["op": "update", "service": service, "status": updateStatus]
        )
        return false
      }
    } else if status != errSecSuccess {
      PostHogSDK.shared.capture(
        "keychain_write_failed",
        properties: ["op": "add", "service": service, "status": status]
      )
      return false
    }

    return true
  }

  func read(service: String, account: String) -> Data? {
    let query =
      [
        kSecAttrService: service,
        kSecAttrAccount: account,
        kSecClass: kSecClassGenericPassword,
        kSecReturnData: true,
        kSecUseDataProtectionKeychain: true,
      ] as CFDictionary

    var result: AnyObject?
    SecItemCopyMatching(query, &result)

    return result as? Data
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
