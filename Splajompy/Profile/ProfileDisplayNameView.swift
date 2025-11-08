import SwiftUI

enum ProfileFontChoiceEnum: Int, CaseIterable, Identifiable, Hashable {
  var id: Int { rawValue }

  case largeTitle2 = 0
  case sixtyFour = 1
  case oldLondon = 2
  case gorton = 3
  case neuton = 4
  case lavish = 5

  var fontName: String? {
    switch self {
    case .largeTitle2: return nil
    case .sixtyFour: return "Sixtyfour-Regular"
    case .oldLondon: return "OldLondon"
    case .gorton: return "OpenGorton-Regular"
    case .neuton: return "Neuton-Regular"
    case .lavish: return "LavishlyYours-Regular"
    }
  }

  var baselineSize: CGFloat {
    switch self {
    case .largeTitle2: return 0
    case .sixtyFour: return 14
    case .oldLondon: return 27
    case .gorton: return 25
    case .neuton: return 24
    case .lavish: return 30
    }
  }
}

struct ProfileDisplayNameView: View {
  var user: PublicUser

  init(user: PublicUser) {
    self.user = user
  }

  init(user: DetailedUser) {
    self.user = PublicUser(from: user)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      if let name = user.name {
        if let fontChoice = ProfileFontChoiceEnum(rawValue: user.displayProperties.fontChoiceId) {
          if let fontName = fontChoice.fontName {
            Text(name)
              .font(Font.custom(fontName, size: fontChoice.baselineSize))
              .lineLimit(1)
          } else {
            Text(name)
              .font(.title2)
              .fontWeight(.black)
              .lineLimit(1)
          }
        } else {
          Text(name)
            .font(.title2)
            .fontWeight(.bold)
        }
      }
    }
  }
}

#Preview("Default LargeTitle2") {
  ProfileDisplayNameView(user: PublicUser(from: Mocks.testUser1))
}

#Preview("Fallback") {
  var testUser1 = Mocks.testUser1
  testUser1.displayProperties = UserDisplayProperties(fontChoiceId: 999)
  return ProfileDisplayNameView(user: PublicUser(from: testUser1))
}

#Preview("Sixtyfour") {
  var testUser1 = Mocks.testUser1
  testUser1.displayProperties = UserDisplayProperties(fontChoiceId: 1)
  return ProfileDisplayNameView(user: PublicUser(from: testUser1))
}

#Preview("Old London") {
  var testUser1 = Mocks.testUser1
  testUser1.displayProperties = UserDisplayProperties(fontChoiceId: 2)
  return ProfileDisplayNameView(user: PublicUser(from: testUser1))
}

#Preview("Gorton") {
  var testUser1 = Mocks.testUser1
  testUser1.displayProperties = UserDisplayProperties(fontChoiceId: 3)
  return ProfileDisplayNameView(user: PublicUser(from: testUser1))
}

#Preview("Neuton") {
  var testUser1 = Mocks.testUser1
  testUser1.displayProperties = UserDisplayProperties(fontChoiceId: 4)
  return ProfileDisplayNameView(user: PublicUser(from: testUser1))
}

#Preview("Lavish") {
  var testUser1 = Mocks.testUser1
  testUser1.displayProperties = UserDisplayProperties(fontChoiceId: 5)
  return ProfileDisplayNameView(user: PublicUser(from: testUser1))
}
