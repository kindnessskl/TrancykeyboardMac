import SwiftUI

struct HorizontalCandidateBarView: View {
    let candidates: [Candidate]
    let input: String
    weak var handler: KeyboardActionHandler?
    
    @ObservedObject var settings: KeyboardSettingsStore
    
    var highlightedIndex: Int
    var currentPage: Int
    var pageSize: Int
    var pageBreakpoints: [Int]
    var candidateWidths: [Int]
    
    private var fontSize: CandidateFontSize { CandidateFontSize(rawValue: settings.candidateFontSize.rawValue) ?? .medium }
    
    private struct PageItem {
        let candidate: Candidate
        let width: Int
    }
    
    private var pageItems: [PageItem] {
        guard currentPage < pageBreakpoints.count else { return [] }
        let start = pageBreakpoints[currentPage]
        let end = (currentPage + 1 < pageBreakpoints.count) ? pageBreakpoints[currentPage + 1] : candidates.count
        
        var items: [PageItem] = []
        for i in start..<end {
            if i < candidateWidths.count {
                items.append(PageItem(candidate: candidates[i], width: candidateWidths[i]))
            }
        }
        return items
    }
        
    var body: some View {
            ZStack(alignment: .leading) {
                if #available(macOS 26.0, *) {
                    HStack(spacing: 32) {
                        ForEach(Array(pageItems.enumerated()), id: \.offset) { index, item in
                            let isHighlighted = (index == highlightedIndex)
                            
                            Button(action: { _ = handler?.selectCandidate(item.candidate, layer: .chinese) }) {
                                HStack(spacing: 0) {
                                    ZStack(alignment: .leading) {
                                        Text("\(index + 1).")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(isHighlighted ? .white : .secondary)
                                    }
                                    .frame(width: 14)
                                    
                                    Text(item.candidate.text)
                                        .font(.system(size: fontSize.chineseSize))
                                        .foregroundColor(isHighlighted ? .white : .primary)
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false)
                                    
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 6)
                                .frame(maxWidth: .infinity, maxHeight: 36)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(isHighlighted ? Color.themeblue : Color.clear)
                                ).padding(2)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .frame(width: CGFloat(item.width))
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.leading, 18)
                    .overlay(
                        Button(action: { _ = handler?.toggleExpansion(force: true) }) {
                            ZStack {
                                Color.clear.frame(width: 40, height: 36)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle()),
                        alignment: .trailing
                    )
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18))
                    
                } else {
                    VisualEffectView(material: .popover, cornerRadius: 18)
                        .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
                }
            }
            .frame(width: 700, height: 36)
        }
    }
