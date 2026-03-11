import Foundation

struct HistoryWord: Equatable {
    let cnId: Int
    let enId: Int
    let englishWord: String
    let chineseWord: String
    let count: Int
    let lastUsedDate: String
    let updatedAt: Int
    let favorite: Bool
    let rank: Int
    let remindData: String
    let chineseTotalCount: Int
    let englishTotalCount: Int
}

struct HistoryStats {
    let dates: [String]
    let todayUsedCount: Int
    let reviewCount: Int
}
