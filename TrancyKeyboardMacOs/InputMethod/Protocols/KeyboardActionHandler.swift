
import Foundation

protocol KeyboardActionHandler: AnyObject {
    // 基础输入
    func handleAlphabet(_ letter: String)
    func handleSeparator()
    func handleBackspace() -> Bool
    func handleSpace() -> Bool
    func handleReturn() -> Bool
    func handlePunctuation(_ key: PunctuationKey, isShift: Bool) -> Bool

    // 选词交互
    func selectIndex(_ index: Int, layer: ActiveLayer?) -> Bool
    func selectCandidate(_ candidate: Candidate, layer: ActiveLayer?) -> Bool
    func moveHighlight(direction: Direction) -> Bool
    func pageDown() -> Bool
    func pageUp() -> Bool

    // 特色交互
    func toggleActiveLayer() -> Bool
    func toggleExpansion(force: Bool?) -> Bool
    func clearInput() -> Bool
}
