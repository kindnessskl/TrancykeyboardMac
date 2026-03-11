import Foundation
import CoreGraphics

enum AppLanguage: String, CaseIterable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"

    var displayName: String {
        switch self {
        case .english: return "English"
        case .simplifiedChinese: return "Chinese_Simplified".localized
        case .traditionalChinese: return "Chinese_Traditional".localized
        }
    }
}
let appLanguageKey = "appLanguage"

enum DualCandidateOutputMode: Int, CaseIterable {
    case `default` = 0
    case chineseOnly = 1
    case englishOnly = 2

    var displayName: String {
        switch self {
        case .default: return "Dual_Mode_Default".localized
        case .chineseOnly: return "Dual_Mode_ChineseOnly".localized
        case .englishOnly: return "Dual_Mode_EnglishOnly".localized
        }
    }
}
let dualCandidateOutputModeKey = "dualCandidateOutputMode"

enum CandidateFontSize: Int, CaseIterable {
    case small = 0
    case medium = 1
    case large = 2
    case size14 = 3
    case size16 = 4
    case size18 = 5

    var displayName: String {
        switch self {
        case .small: return "16"
        case .medium: return "18"
        case .large: return "24"
        case .size14: return "14"
        case .size16: return "20"
        case .size18: return "26"
        }
    }

    var chineseSize: CGFloat {
        switch self {
        case .small: return 16
        case .medium: return 18
        case .large: return 24
        case .size14: return 14
        case .size16: return 20
        case .size18: return 26
        }
    }

    var englishSize: CGFloat {
        switch self {
        case .small: return 14
        case .medium: return 16
        case .large: return 22
        case .size14: return 12
        case .size16: return 18
        case .size18: return 24
        }
    }
}
let candidateFontSizeKey = "candidateFontSize"

enum CandidateSpacing: Int, CaseIterable {
    case tight = 0
    case normal = 1
    case wide = 2

    var displayName: String {
        switch self {
        case .tight: return "Spacing_Tight".localized
        case .normal: return "Spacing_Normal".localized
        case .wide: return "Spacing_Wide".localized
        }
    }

    var padding: CGFloat {
        switch self {
        case .tight: return 10
        case .normal: return 16
        case .wide: return 24
        }
    }
}
let candidateSpacingKey = "candidateSpacing"

extension Notification.Name {
    static let candidateFontSizeDidChange = Notification.Name("candidateFontSizeDidChange")
    static let candidateSpacingDidChange = Notification.Name("candidateSpacingDidChange")
}

struct KeyboardConstants {
    struct Layout {
        static let keySpacing: CGFloat = 6
        static let keyCornerRadius: CGFloat = 8
    }
    
    struct Theme {
        static var baseKeyboardHeight: CGFloat = 210
    }
    
    struct Haptics {
        static var enableHapticFeedback = false
        static let lightImpactForNormalKeys = false
        static let mediumImpactForSpecialKeys = false
        static let heavyImpactForDelete = false
    }

    struct Sound {
        static var enableSoundFeedback = false
        static let keyClickSoundID: UInt32 = 1104
        static let deleteKeySoundID: UInt32 = 1155
        static let modifierKeySoundID: UInt32 = 1156
    }
}

struct KeyboardSkinModel: Codable, Identifiable {
    var id: String
    var name: String
    var keyBackgroundColor: String
    var keyHighlightColor: String
    var keyTextColor: String
    var specialKeyBackgroundColor: String
    var specialKeyTextColor: String
    var candidateBarBackgroundColor: String
    var candidateTextColor: String
    var keyboardBackgroundColor: String
}

import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

extension Color {
    static let themeblue = Color(hex: "5288fc")
}
