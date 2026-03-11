import SwiftUI

struct KeyboardModeViewFactory {
    @MainActor
    static func createModeView(
        for mode: InputMode,
        candidates: [Candidate],
        translations: [[String]]?,
        input: String,
        handler: KeyboardActionHandler?,
        settings: KeyboardSettingsStore,
        activeLayer: ActiveLayer,
        highlightedIndex: Int,
        currentPage: Int,
        pageSize: Int,
        pageBreakpoints: [Int],
        candidateWidths: [Int],
        isExpanded: Bool
    ) -> AnyView {
        switch mode {
        case .chinese:
            return AnyView(
                ChineseModeView(
                    candidates: candidates,
                    input: input,
                    handler: handler,
                    settings: settings,
                    inputMode: mode,
                    activeLayer: activeLayer,
                    highlightedIndex: highlightedIndex,
                    currentPage: currentPage,
                    pageSize: pageSize,
                    pageBreakpoints: pageBreakpoints,
                    candidateWidths: candidateWidths,
                    isExpanded: isExpanded
                )
            )
        case .chinesePreview:
            return AnyView(
                ChinesePreviewModeView(
                    candidates: candidates,
                    translations: translations,
                    input: input,
                    handler: handler,
                    settings: settings,
                    inputMode: mode,
                    activeLayer: activeLayer,
                    highlightedIndex: highlightedIndex,
                    currentPage: currentPage,
                    pageSize: pageSize,
                    pageBreakpoints: pageBreakpoints,
                    candidateWidths: candidateWidths,
                    isExpanded: isExpanded
                )
            )
        }
    }
}
