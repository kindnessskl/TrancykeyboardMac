import Foundation

struct LearningRecord: Equatable, Identifiable, Codable {
    let id: Int
    let cnId: Int
    let enId: Int
    let englishWord: String
    let chineseWord: String
    let pos: String
    let meaning: String
    let ipa: String
    let example: String
    let exampleCn: String
    let frequency: Int
    let count: Int
    let lastUsedDate: String
    let categoryType: String
    let groupNum: Int
    let favorite: Bool
    let rank: Int
    let remindData: String
    let mark: String
    let photoIdentifier: String
    let photoPath: String
}
