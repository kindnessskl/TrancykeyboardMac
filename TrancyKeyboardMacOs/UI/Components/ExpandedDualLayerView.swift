import SwiftUI

struct ExpandedDualLayerView: View {
    let candidates: [Candidate]
    let translations: [[String]]?
    weak var handler: KeyboardActionHandler?

    @ObservedObject var settings: KeyboardSettingsStore
    @State private var sortMode: SortMode = .frequency
    
    var inputMode: InputMode
    var activeLayer: ActiveLayer
    var highlightedIndex: Int
    var currentPage: Int
    var pageSize: Int
    var pageBreakpoints: [Int]
    var candidateWidths: [Int]

    private var fontSize: CandidateFontSize { CandidateFontSize(rawValue: settings.candidateFontSize.rawValue) ?? .medium }

    var body: some View {
        if #available(macOS 26.0, *) {
            ZStack {
                VStack(spacing: 0) {
                    contentArea
                    Divider()
                    bottomSortBar
                }
            }
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
            .frame(width: 700, height: 400)
        } else {
            VisualEffectView(material: .popover, cornerRadius: 18)
            .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
        }
    }

    private var contentArea: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .topTrailing) { 
                scrollViewArea(proxy: proxy)
                
                Button(action: { _ = handler?.toggleExpansion(force: false) }) {
                    ZStack {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private func scrollViewArea(proxy: ScrollViewProxy) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(groupedSections, id: \.title) { section in
                    sectionContentView(section)
                }
            }
            .padding(.bottom, 10)
            .padding(.trailing, 40)
        }
        .onChange(of: currentPage) { oldValue, newValue in
            scrollToCurrentPage(proxy: proxy, newPage: newValue)
        }
    }

    private func sectionContentView(_ section: ExpandedSectionData) -> some View {
        Section(header: SectionHeader(title: section.title)) {
            VStack(alignment: .leading, spacing: 0) {
                let rows = makeRows(from: section.items)
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    CandidateGridRow(
                        row: row,
                        translations: translations,
                        allCandidates: candidates,
                        inputMode: inputMode,
                        fontSize: fontSize,
                        activeLayer: activeLayer,
                        isCandidateHighlighted: isCandidateHighlighted,
                        indexInPage: indexInPage,
                        handler: handler
                    )
                    .id(row.items.first?.0.text)
                }
            }
        }
        .id(section.title ?? "top")
    }

    private var bottomSortBar: some View {
        HStack {
            Spacer()
            Picker("", selection: $sortMode) {
                ForEach(SortMode.allCases, id: \.self) { mode in
                    Text(mode.title).font(.system(size: 20)).tag(mode)
                }
            }
            .pickerStyle(SegmentedPickerStyle()).frame(width: 360)
            Spacer()
        }
        .padding(10)
        .background(Color.primary.opacity(0.02))
    }

    private func scrollToCurrentPage(proxy: ScrollViewProxy, newPage: Int) {
        guard newPage < pageBreakpoints.count else { return }
        let firstIdx = pageBreakpoints[newPage]
        guard firstIdx < candidates.count else { return }
        let targetCandidate = candidates[firstIdx]
        
        withAnimation(.easeInOut(duration: 0.2)) {
            proxy.scrollTo(targetCandidate.text)
        }
    }

    private func makeRows(from items: [Candidate]) -> [RowData] {
        var rows: [RowData] = []
        
        for i in 0..<pageBreakpoints.count {
            let start = pageBreakpoints[i]
            let end = (i + 1 < pageBreakpoints.count) ? pageBreakpoints[i + 1] : candidates.count
            
            let sectionRowItems = candidates[start..<end].filter { cand in
                items.contains { $0.text == cand.text && $0.pinyin == cand.pinyin }
            }
            
            if !sectionRowItems.isEmpty {
                let rowItemsWithWidth = sectionRowItems.map { cand -> (Candidate, Int) in
                    let globalIdx = candidates.firstIndex(of: cand) ?? -1
                    let width = (globalIdx >= 0 && globalIdx < candidateWidths.count) ? candidateWidths[globalIdx] : 100
                    return (cand, width)
                }
                rows.append(RowData(items: rowItemsWithWidth))
            }
        }
        return rows
    }

    private func isCandidateHighlighted(_ candidate: Candidate) -> Bool {
        guard currentPage < pageBreakpoints.count else { return false }
        let start = pageBreakpoints[currentPage]
        let end = (currentPage + 1 < pageBreakpoints.count) ? pageBreakpoints[currentPage + 1] : candidates.count
        let pageItems = candidates[start..<end]
        if let idxInPage = pageItems.firstIndex(of: candidate) {
            return (idxInPage - start) == highlightedIndex
        }
        return false
    }

    private func indexInPage(for candidate: Candidate) -> Int? {
        guard currentPage < pageBreakpoints.count else { return nil }
        let start = pageBreakpoints[currentPage]
        let end = (currentPage + 1 < pageBreakpoints.count) ? pageBreakpoints[currentPage + 1] : candidates.count
        
        let pageItems = candidates[start..<end]
        if let idxInPage = pageItems.firstIndex(of: candidate) {
            return (idxInPage - start) + 1
        }
        return nil
    }

    private var groupedSections: [ExpandedSectionData] {
        switch sortMode {
        case .frequency: return [ExpandedSectionData(title: nil, items: candidates)]
        case .pinyin:
            let groups = Dictionary(grouping: candidates, by: { String($0.pinyin).lowercased() })
            return groups.keys.sorted().map { key in
                let sortedItems = (groups[key] ?? []).sorted { $0.text.count < $1.text.count }
                return ExpandedSectionData(title: key, items: sortedItems)
            }
        case .stroke:
            let groups = Dictionary(grouping: candidates, by: { "\($0.strokeCount)" })
            let sortedKeys = groups.keys.compactMap { Int($0) }.sorted()
            return sortedKeys.map { ExpandedSectionData(title: "\($0)画", items: groups["\($0)"] ?? []) }
        }
    }
}

private struct CandidateGridRow: View {
    let row: RowData
    let translations: [[String]]?
    let allCandidates: [Candidate]
    let inputMode: InputMode
    let fontSize: CandidateFontSize
    let activeLayer: ActiveLayer
    let isCandidateHighlighted: (Candidate) -> Bool
    let indexInPage: (Candidate) -> Int?
    weak var handler: KeyboardActionHandler?

    var body: some View {
        HStack(spacing: 32) {
            ForEach(Array(row.items.enumerated()), id: \.offset) { _, pair in
                let (candidate, width) = pair
                let globalIdx = allCandidates.firstIndex(of: candidate) ?? 0
                let translation = (inputMode == .chinesePreview && translations != nil && globalIdx < translations!.count) ? translations![globalIdx].first ?? "" : ""
                ExpandedGridCell(
                    candidate: candidate,
                    translation: translation,
                    inputMode: inputMode,
                    fontSize: fontSize,
                    isHighlighted: isCandidateHighlighted(candidate),
                    activeLayer: activeLayer,
                    indexInPage: indexInPage(candidate),
                    onSelect: { layer in _ = handler?.selectCandidate(candidate, layer: layer) }
                )
                .frame(width: CGFloat(width))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

private struct ExpandedGridCell: View {
    let candidate: Candidate
    let translation: String
    let inputMode: InputMode
    let fontSize: CandidateFontSize
    let isHighlighted: Bool
    let activeLayer: ActiveLayer
    let indexInPage: Int?
    let onSelect: (ActiveLayer) -> Void

    var body: some View {
        VStack(spacing: 0) {
            expandedCellRow(text: candidate.text, size: fontSize.chineseSize, layer: .chinese)
            if inputMode == .chinesePreview {
                if !translation.isEmpty {
                    expandedCellRow(text: translation, size: fontSize.englishSize, layer: .english)
                } else {
                    Color.clear.frame(height: 30)
                }
            }
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func expandedCellRow(text: String, size: CGFloat, layer: ActiveLayer) -> some View {
        let isLayerActive = (activeLayer == layer)
        Button(action: { onSelect(layer) }) {
            HStack(spacing: 0) {
                ZStack(alignment: .leading) {
                    if let num = indexInPage {
                        Text("\(num).")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(isHighlighted ? .white : .secondary)
                            .opacity(isLayerActive ? 1 : 0)
                    }
                }
                .frame(width: 14)
                
                Text(text)
                    .font(.system(size: size))
                    .foregroundColor(isHighlighted && isLayerActive  ? .white : .primary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 30)
            .background(RoundedRectangle(cornerRadius: 16).fill(isHighlighted && isLayerActive ? Color.themeblue : Color.clear))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct RowData { let items: [(Candidate, Int)] }
private struct ExpandedSectionData { let title: String?; let items: [Candidate] }
private struct SectionHeader: View {
    let title: String?
    var body: some View {
        if let title = title {
            HStack {
                Text(title).font(.system(size: 13, weight: .bold)).foregroundColor(.secondary).padding(.horizontal, 16).padding(.vertical, 4)
                Spacer()
            }
            .background(VisualEffectView().opacity(0.95))
        }
    }
}
private enum SortMode: Int, CaseIterable {
    case frequency = 0; case pinyin = 1; case stroke = 2
    var title: String { switch self { case .frequency: return "Sort_Frequency".localized; case .pinyin: return "Sort_Pinyin".localized; case .stroke: return "Sort_Stroke".localized } }
}
