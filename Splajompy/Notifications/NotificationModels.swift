struct DeviceRegisterRequest: Codable {
  let token: String
  var comments: Bool
  var mentions: Bool
  var followers: Bool
}
