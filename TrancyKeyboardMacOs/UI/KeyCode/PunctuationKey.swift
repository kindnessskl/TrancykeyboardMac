import Foundation

struct PunctuationKey: Hashable {
    let keyText: String
    let shiftingKeyText: String
    let chineseSymbol: String
    let chineseShiftingSymbol: String

    static let comma = PunctuationKey(keyText: ",", shiftingKeyText: "<", chineseSymbol: "，", chineseShiftingSymbol: "《")
    static let period = PunctuationKey(keyText: ".", shiftingKeyText: ">", chineseSymbol: "。", chineseShiftingSymbol: "》")
    static let slash = PunctuationKey(keyText: "/", shiftingKeyText: "?", chineseSymbol: "／", chineseShiftingSymbol: "？")
    static let semicolon = PunctuationKey(keyText: ";", shiftingKeyText: ":", chineseSymbol: "；", chineseShiftingSymbol: "：")
    static let quote = PunctuationKey(keyText: "'", shiftingKeyText: "\"", chineseSymbol: "‘", chineseShiftingSymbol: "“")
    static let bracketLeft = PunctuationKey(keyText: "[", shiftingKeyText: "{", chineseSymbol: "「", chineseShiftingSymbol: "『")
    static let bracketRight = PunctuationKey(keyText: "]", shiftingKeyText: "}", chineseSymbol: "」", chineseShiftingSymbol: "』")
    static let backSlash = PunctuationKey(keyText: "\\", shiftingKeyText: "|", chineseSymbol: "、", chineseShiftingSymbol: "｜")
    static let backquote = PunctuationKey(keyText: "`", shiftingKeyText: "~", chineseSymbol: "·", chineseShiftingSymbol: "～")
    static let minus = PunctuationKey(keyText: "-", shiftingKeyText: "_", chineseSymbol: "－", chineseShiftingSymbol: "——")
    static let equal = PunctuationKey(keyText: "=", shiftingKeyText: "+", chineseSymbol: "＝", chineseShiftingSymbol: "＋")
}


