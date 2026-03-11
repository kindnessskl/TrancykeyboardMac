
import Foundation

protocol KeyboardActionHandler: AnyObject {
    func handleAlphabet(_ letter: String)
    func handleSeparator()
    func handleBackspace() -> Bool
    func handleSpace() -> Bool
    func handleReturn() -> Bool
    func handlePunctuation(_ key: PunctuationKey, isShift: Bool) -> Bool

    func selectIndex(_ index: Int, layer: ActiveLayer?) -> Bool
    func selectCandidate(_ candidate: Candidate, layer: ActiveLayer?) -> Bool
    func moveHighlight(direction: Direction) -> Bool
    func pageDown() -> Bool
    func pageUp() -> Bool

    func toggleActiveLayer() -> Bool
    func toggleExpansion(force: Bool?) -> Bool
    func clearInput() -> Bool
}
