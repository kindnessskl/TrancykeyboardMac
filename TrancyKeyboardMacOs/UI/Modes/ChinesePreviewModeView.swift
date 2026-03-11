import SwiftUI

struct ChinesePreviewModeView: View {
    let candidates: [Candidate]
    let translations: [[String]]?
    let input: String
    weak var handler: KeyboardActionHandler?

    @ObservedObject var settings: KeyboardSettingsStore
    
    // 交互状态
    var inputMode: InputMode
    var activeLayer: ActiveLayer
    var highlightedIndex: Int
    var currentPage: Int
    var pageSize: Int
    var pageBreakpoints: [Int]
    var candidateWidths: [Int]
    var isExpanded: Bool

    var body: some View {
        VStack(spacing: 0) {
            if isExpanded {
                ExpandedDualLayerView(
                    candidates: candidates,
                    translations: translations,
                    handler: handler,
                    settings: settings,
                    inputMode: .chinesePreview,
                    activeLayer: activeLayer,
                    highlightedIndex: highlightedIndex,
                    currentPage: currentPage,
                    pageSize: pageSize,
                    pageBreakpoints: pageBreakpoints,
                    candidateWidths: candidateWidths
                )
            } else {
                DualLayerCandidateBarView(
                    candidates: candidates,
                    translations: translations,
                    input: input,
                    handler: handler,
                    settings: settings,
                    activeLayer: activeLayer,
                    highlightedIndex: highlightedIndex,
                    currentPage: currentPage,
                    pageSize: pageSize,
                    pageBreakpoints: pageBreakpoints,
                    candidateWidths: candidateWidths
                )
            }
        }
    }
}
