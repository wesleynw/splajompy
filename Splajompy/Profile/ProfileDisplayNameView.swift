import SwiftUI

enum ProfileFontChoiceEnum: Int, CaseIterable, Identifiable, Hashable {
  var id: Int { rawValue }
  
  case largeTitle2 = 0
  case sixtyFour = 1
  case unifraktur = 2
  case gorton = 3
  case neuton = 4
  case monsieur = 5
  case griefswalder = 6

  var fontName: String? {
    switch self {
    case .largeTitle2: return nil
    case .sixtyFour: return "Sixtyfour-Regular"
    case .unifraktur: return "UnifrakturMaguntia"
    case .gorton: return "OpenGorton-Regular"
    case .neuton: return "Neuton-Regular"
    case .monsieur: return "MonsieurLaDoulaise-Regular"
    case .griefswalder: return "GreifswalderDeutscheSchrift"
    }
  }

  var baselineSize: CGFloat {
    switch self {
    case .largeTitle2: return 0
    case .sixtyFour: return 14
    case .unifraktur: return 25
    case .gorton: return 20
    case .neuton: return 24
    case .monsieur: return 35
    case .griefswalder: return 30
    }
  }
}

struct ProfileDisplayNameView: View {
  var user: DetailedUser

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      if let name = user.name {
        if let fontChoice = ProfileFontChoiceEnum(rawValue: user.fontChoiceId) {
          if let fontName = fontChoice.fontName {
            Text(name)
              .font(Font.custom(fontName, size: fontChoice.baselineSize))
          } else {
            Text(name)
              .font(.title2)
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
  ProfileDisplayNameView(user: Mocks.testUser1)
}

#Preview("Fallback") {
  var testUser1 = Mocks.testUser1
  testUser1.fontChoiceId = 999
  return ProfileDisplayNameView(user: testUser1)
}

#Preview("Sixtyfour") {
  var testUser1 = Mocks.testUser1
  testUser1.fontChoiceId = 1
  return ProfileDisplayNameView(user: testUser1)
}

#Preview("Unifraktur") {
  var testUser1 = Mocks.testUser1
  testUser1.fontChoiceId = 2
  return ProfileDisplayNameView(user: testUser1)
}

#Preview("Gorton") {
  var testUser1 = Mocks.testUser1
  testUser1.fontChoiceId = 3
  return ProfileDisplayNameView(user: testUser1)
}

#Preview("Neuton") {
  var testUser1 = Mocks.testUser1
  testUser1.fontChoiceId = 4
  return ProfileDisplayNameView(user: testUser1)
}

#Preview("Monsieur") {
  var testUser1 = Mocks.testUser1
  testUser1.fontChoiceId = 5
  return ProfileDisplayNameView(user: testUser1)
}

#Preview("Greifswalder") {
  var testUser1 = Mocks.testUser1
  testUser1.fontChoiceId = 6
  return ProfileDisplayNameView(user: testUser1)
}
