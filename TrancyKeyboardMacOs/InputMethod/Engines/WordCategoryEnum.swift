import Foundation

struct CategoryDisplayItem: Identifiable {
    let id = UUID()
    let type: WordCategory
    let count: Int
}
enum WordCategoryGroup {
    case word
    case phrase
}
enum WordCategory: String, CaseIterable {
      case top5000 = "top5000"
      case top15000 = "top15000"
      case commonVerbs = "常用动词"
      case verbPhrases500 = "常用动词短语500"
      case slang500 = "俚语500"
      case common45000 = "common45000"
      case api = "api"
      case userAdded = "user_added"
      case chunk = "chunk"
      case sentence = "sentence"

      var displayName: String {
          switch self {
          case .top5000:
              return "Category_Top5000".localized
          case .top15000:
              return "Category_Top15000".localized
          case .commonVerbs:
              return "Category_Verbs".localized
          case .verbPhrases500:
              return "Category_Phrases".localized
          case .slang500:
              return "Category_Slang".localized
          case .common45000:
              return "Category_Common45000".localized
          case .api:
              return "Category_API".localized
          case .userAdded:
              return "Category_UserAdded".localized
          case .chunk:
              return "Category_chunk".localized
          case .sentence:
              return "Category_sentence".localized
          }
      }
  
    
    func getGroupCount(totalWords: Int) -> Int {
        return (totalWords + 99) / 100
    }
    
    func getGroupRange(groupIndex: Int) -> (start: Int, end: Int) {
        let start = groupIndex * 100 + 1
        let end = (groupIndex + 1) * 100
        return (start, end)
    }
    
}

extension WordCategory {
    var groupType: WordCategoryGroup {
        switch self {
        case .top5000, .top15000, .commonVerbs, .common45000, .api, .userAdded:
            return .word
        case .verbPhrases500, .slang500, .chunk, .sentence:
            return .phrase
        }
    }
}

struct WordGroup: Identifiable {
    let id = UUID()
    let groupIndex: Int
    let count: Int
    
    var rangeText: String {
        let start = groupIndex * 100 + 1
        let end = start + count - 1
        return "\(start) - \(end)"
    }
}
