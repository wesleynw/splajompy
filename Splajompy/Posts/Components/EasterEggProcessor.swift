import Foundation

class EasterEggProcessor {
  struct EasterEggResult {
    let shouldTrigger: Bool
    let processedText: String
    let triggerUsername: String
    let adjustedFacets: [Facet]
  }

  static func processTripleUsernameEasterEgg(_ text: String, facets: [Facet]) -> EasterEggResult {
    let sortedFacets = facets.sorted { $0.indexStart < $1.indexStart }

    guard let triggerInfo = findTriggerUsername(in: sortedFacets, text: text) else {
      return EasterEggResult(
        shouldTrigger: false, processedText: text, triggerUsername: "", adjustedFacets: facets)
    }

    let result = createSimpleGlitchReplacement(
      text, facets: sortedFacets, triggerUserId: triggerInfo.userId,
      triggerUsername: triggerInfo.username)

    return EasterEggResult(
      shouldTrigger: true,
      processedText: result.text,
      triggerUsername: triggerInfo.username,
      adjustedFacets: result.facets
    )
  }

  private static func createSimpleGlitchReplacement(
    _ text: String, facets: [Facet], triggerUserId: Int, triggerUsername: String
  ) -> (text: String, facets: [Facet]) {
    let mentionFacets = facets.filter { $0.type == "mention" && $0.userId == triggerUserId }.sorted
    { $0.indexStart < $1.indexStart }
    let otherFacets = facets.filter { $0.type != "mention" || $0.userId != triggerUserId }

    var firstThreeGroup: [Facet]?
    var i = 0
    while i + 2 < mentionFacets.count {
      let first = mentionFacets[i]
      let second = mentionFacets[i + 1]
      let third = mentionFacets[i + 2]

      if second.indexStart <= first.indexEnd + 2 && third.indexStart <= second.indexEnd + 2 {
        firstThreeGroup = [first, second, third]
        break
      }
      i += 1
    }

    guard let threeGroup = firstThreeGroup else {
      return (text: text, facets: facets)
    }
    let replaceStart = threeGroup[0].indexStart
    let replaceEnd = threeGroup[2].indexEnd
    let glitchReplacement = "@\(triggerUsername)"

    var processedText = text
    let startIndex = processedText.index(processedText.startIndex, offsetBy: replaceStart)
    let endIndex = processedText.index(processedText.startIndex, offsetBy: replaceEnd)
    processedText.replaceSubrange(startIndex..<endIndex, with: glitchReplacement)

    let lengthDiff = glitchReplacement.count - (replaceEnd - replaceStart)

    var adjustedFacets: [Facet] = []
    let remainingTriggerMentions = mentionFacets.dropFirst(3)
    for mention in remainingTriggerMentions {
      let adjustedStart = mention.indexStart + lengthDiff
      let adjustedEnd = mention.indexEnd + lengthDiff

      if adjustedStart >= 0 && adjustedEnd <= processedText.count {
        adjustedFacets.append(
          Facet(
            type: mention.type,
            userId: mention.userId,
            indexStart: adjustedStart,
            indexEnd: adjustedEnd
          ))
      }
    }

    for facet in otherFacets {
      if facet.indexStart >= replaceEnd {
        let adjustedStart = facet.indexStart + lengthDiff
        let adjustedEnd = facet.indexEnd + lengthDiff

        if adjustedStart >= 0 && adjustedEnd <= processedText.count {
          adjustedFacets.append(
            Facet(
              type: facet.type,
              userId: facet.userId,
              indexStart: adjustedStart,
              indexEnd: adjustedEnd
            ))
        }
      } else {
        adjustedFacets.append(facet)
      }
    }

    return (text: processedText, facets: adjustedFacets.sorted { $0.indexStart < $1.indexStart })
  }

  private static func findTriggerUsername(in facets: [Facet], text: String) -> (
    userId: Int, username: String
  )? {
    var currentUserId: Int?
    var consecutiveCount = 0

    for facet in facets {
      if facet.type == "mention" {
        if facet.userId == currentUserId {
          consecutiveCount += 1
          if consecutiveCount >= 3 {
            let startIndex = text.index(text.startIndex, offsetBy: facet.indexStart + 1)
            let endIndex = text.index(text.startIndex, offsetBy: facet.indexEnd)
            let username = String(text[startIndex..<endIndex]).lowercased()
            return (userId: facet.userId, username: username)
          }
        } else {
          currentUserId = facet.userId
          consecutiveCount = 1
        }
      } else {
        currentUserId = nil
        consecutiveCount = 0
      }
    }
    return nil
  }
}
