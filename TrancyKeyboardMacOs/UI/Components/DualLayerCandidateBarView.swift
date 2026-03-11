import SwiftUI

struct DualLayerCandidateBarView: View {
    let candidates: [Candidate]
    let translations: [[String]]?
    let input: String
    weak var handler: KeyboardActionHandler?

    @ObservedObject var settings: KeyboardSettingsStore
    
    var activeLayer: ActiveLayer
    var highlightedIndex: Int
    var currentPage: Int
    var pageSize: Int
    var pageBreakpoints: [Int]
    var candidateWidths: [Int]

    private var fontSize: CandidateFontSize { CandidateFontSize(rawValue: settings.candidateFontSize.rawValue) ?? .medium }

    private struct PageItem {
        let candidate: Candidate
        let width: Int
        let globalIdx: Int
    }

    private var pageItems: [PageItem] {
        guard currentPage < pageBreakpoints.count else { return [] }
        let start = pageBreakpoints[currentPage]
        let end = (currentPage + 1 < pageBreakpoints.count) ? pageBreakpoints[currentPage + 1] : candidates.count
        
        var items: [PageItem] = []
        for i in start..<end {
            if i < candidateWidths.count {
                items.append(PageItem(candidate: candidates[i], width: candidateWidths[i], globalIdx: i))
            }
        }
        return items
    }

    var body: some View {
        if #available(macOS 26.0, *) {
            ZStack(alignment: .leading) {
                HStack(spacing: 32) {
                    ForEach(Array(pageItems.enumerated()), id: \.offset) { index, item in
                        let isHighlighted = (index == highlightedIndex)
                        let translation = (translations != nil && item.globalIdx < translations!.count) ? translations![item.globalIdx].first ?? "" : ""
                        
                        DualCandidateCell(
                            candidate: item.candidate,
                            translation: translation,
                            fontSize: fontSize,
                            isHighlighted: isHighlighted,
                            activeLayer: activeLayer,
                            indexInPage: index + 1,
                            onSelect: { layer in _ = handler?.selectCandidate(item.candidate, layer: layer) }
                        )
                        .frame(width: CGFloat(item.width))
                    }
                    
                    Spacer(minLength: 0)
                }
                .padding(.leading, 20)
            }
            .overlay(
                Button(action: { _ = handler?.toggleExpansion(force: true) }) {
                    ZStack {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 40, height: 60) 
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle()),
                alignment: .trailing
            )
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
            .frame(width: 700, height: 70)
        } else {
            VisualEffectView(material: .popover, cornerRadius: 16)
                .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
        }
    }
}
private struct DualCandidateCell: View {
    let candidate: Candidate
    let translation: String
    let fontSize: CandidateFontSize
    let isHighlighted: Bool
    let activeLayer: ActiveLayer
    let indexInPage: Int
    let onSelect: (ActiveLayer) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cellRow(text: candidate.text, size: fontSize.chineseSize, layer: .chinese)
            
            if !translation.isEmpty {
                cellRow(text: translation, size: fontSize.englishSize, layer: .english)
            } else {
                Color.clear.frame(height: 30)
            }
        }.padding(4) //
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func cellRow(text: String, size: CGFloat, layer: ActiveLayer) -> some View {
        let isLayerActive = (activeLayer == layer)
        
        Button(action: { onSelect(layer) }) {
            HStack(spacing: 0) {
                Text("\(indexInPage).")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(isHighlighted && isLayerActive ? .white : .secondary)
                    .opacity(isLayerActive ? 1 : 0)
                    .frame(width: 14, alignment: .leading)

                Text(text)
                    .font(.system(size: size))
                    .foregroundColor(isHighlighted && isLayerActive ? .white : .primary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, minHeight: 30)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isHighlighted && isLayerActive ? Color.themeblue : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
