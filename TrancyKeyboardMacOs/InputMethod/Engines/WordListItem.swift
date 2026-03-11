import Foundation

struct WordListItem: Equatable {
    let enId: Int
    let englishWord: String
    let pos: String
    let meaning: String
    let ipa: String
    let example: String
    let rank: Int
    let remindData: String
    let favorite: Bool
    let frequency: Int
}