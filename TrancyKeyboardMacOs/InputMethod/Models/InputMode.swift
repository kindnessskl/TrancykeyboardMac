import Foundation

enum InputMode: String, Codable, CaseIterable {
        case chinese

        case chinesePreview

        var displayName: String {
        switch self {
        case .chinese:
            return "Mode_Chinese".localized
        case .chinesePreview:
            return "Mode_ChinesePreview".localized
        }
    }

        var description: String {
        switch self {
        case .chinese:
            return "Desc_Chinese".localized
        case .chinesePreview:
            return "Desc_ChinesePreview".localized
        }
    }
}

extension InputMode: Hashable, Equatable {}

