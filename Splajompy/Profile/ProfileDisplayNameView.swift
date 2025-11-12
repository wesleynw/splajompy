import PostHog
import SwiftUI

enum ProfileFontChoiceEnum: Int, CaseIterable, Identifiable, Hashable {
  var id: Int { rawValue }

  case largeTitle2 = 0
  case sixtyFour = 1
  case oldLondon = 2
  case gorton = 3
  case neuton = 4
  case lavish = 5
  case swanky = 6
  case cooperBlack = 7
  case alienMushrooms = 8

  var fontName: String? {
    switch self {
    case .largeTitle2: return nil
    case .sixtyFour: return "Sixtyfour-Regular"
    case .oldLondon: return "OldLondon"
    case .gorton: return "OpenGorton-Regular"
    case .neuton: return "Neuton-Regular"
    case .lavish: return "LavishlyYours-Regular"
    case .swanky: return "FontdinerSwanky-Regular"
    case .cooperBlack: return "CooperBlackStd"
    case .alienMushrooms: return "AlienMushrooms"
    }
  }

  var baselineSize: CGFloat {
    switch self {
    case .largeTitle2: return 0
    case .sixtyFour: return 14
    case .oldLondon: return 24
    case .gorton: return 25
    case .neuton: return 24
    case .lavish: return 28
    case .swanky: return 18
    case .cooperBlack: return 20
    case .alienMushrooms: return 24
    }
  }

  var titleSize: CGFloat {
    switch self {
    case .largeTitle2: return 0
    case .sixtyFour: return 20
    case .oldLondon: return 30
    case .gorton: return 25
    case .neuton: return 30
    case .lavish: return 34
    case .swanky: return 24
    case .cooperBlack: return 25
    case .alienMushrooms: return 34
    }
  }
}

struct ProfileDisplayNameView: View {
  var user: PublicUser
  var isLargeTitle: Bool
  var isShowingUsername: Bool
  var isAligningVertically: Bool

  init(
    user: PublicUser,
    largeTitle: Bool = false,
    showUsername: Bool = true,
    alignVertically: Bool = true
  ) {
    self.user = user
    self.isLargeTitle = largeTitle
    self.isShowingUsername = showUsername
    self.isAligningVertically = alignVertically
  }

  init(
    user: DetailedUser,
    largeTitle: Bool = false,
    showUsername: Bool = true,
    alignVertically: Bool = true
  ) {
    self.init(
      user: PublicUser(from: user),
      largeTitle: largeTitle,
      showUsername: showUsername,
      alignVertically: alignVertically
    )
  }

  var body: some View {
    if isAligningVertically {
      VStack(alignment: .leading) {
        content
      }
    } else {
      HStack(alignment: .firstTextBaseline) {
        content
      }
    }
  }

  @ViewBuilder
  private var content: some View {
    if let name = user.name, !name.isEmpty {
      if let displayProperties = user.displayProperties,
        let fontChoiceId = displayProperties.fontChoiceId,
        let fontChoice = ProfileFontChoiceEnum(rawValue: fontChoiceId),
        let fontName = fontChoice.fontName,
        PostHogSDK.shared.isFeatureEnabled("custom-profile-fonts")
      {
        Text(name)
          .font(
            Font.custom(
              fontName,
              size: isLargeTitle
                ? fontChoice.titleSize : fontChoice.baselineSize,
              relativeTo: isLargeTitle ? .title2 : .body
            )
          )
          .lineLimit(1)
      } else {
        Text(name)
          .font(isLargeTitle ? .title2 : .body)
          .fontWeight(.black)
          .lineLimit(1)
      }

      if isShowingUsername {
        Text("@" + user.username)
          .font(isLargeTitle ? .subheadline : .footnote)
          .foregroundStyle(.secondary)
          .fontWeight(.black)
          .lineLimit(1)
      }
    } else if isShowingUsername {
      Text("@" + user.username)
        .font(isLargeTitle ? .title2 : .body)
        .foregroundStyle(.secondary)
        .fontWeight(.black)
        .lineLimit(1)
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

#Preview("Swanky") {
  var testUser1 = Mocks.testUser1
  testUser1.displayProperties = UserDisplayProperties(fontChoiceId: 6)
  return ProfileDisplayNameView(user: PublicUser(from: testUser1))
}

#Preview("Cooper Black") {
  var testUser1 = Mocks.testUser1
  testUser1.displayProperties = UserDisplayProperties(fontChoiceId: 7)
  return ProfileDisplayNameView(user: PublicUser(from: testUser1))
}
