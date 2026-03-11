import SwiftUI
import Translation
import Combine

@available(iOS 18.0, macOS 15.0, *)
class TranslationServiceViewModel: ObservableObject {
    @Published var configuration: TranslationSession.Configuration?
    var currentBatchTexts: [String] = []
    
    private var pendingBatchCompletion: (([(original: String, translated: String)]) -> Void)?

    func requestBatchTranslation(texts: [String], from sourceLanguage: String, to targetLanguage: String, completion: @escaping ([(original: String, translated: String)]) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            print("📖 [TranslationService] 批量翻译请求 | 数量=\(texts.count)")
            self.currentBatchTexts = texts
            self.pendingBatchCompletion = completion

            let newSource = Locale.Language(identifier: sourceLanguage)
            let newTarget = Locale.Language(identifier: targetLanguage)

            if self.configuration?.source == newSource,
               self.configuration?.target == newTarget {
                self.configuration?.invalidate()
            } else {
                self.configuration = TranslationSession.Configuration(
                    source: newSource,
                    target: newTarget
                )
            }
        }
    }

    func requestTranslation(text: String, from sourceLanguage: String, to targetLanguage: String, completion: @escaping (String, String) -> Void) {
        requestBatchTranslation(texts: [text], from: sourceLanguage, to: targetLanguage) { results in
            if let first = results.first {
                completion(first.original, first.translated)
            }
        }
    }
    
    func handleResults(_ results: [(String, String)]) {
        pendingBatchCompletion?(results)
        pendingBatchCompletion = nil
    }

    func reset() {
        configuration = nil
        currentBatchTexts = []
        pendingBatchCompletion = nil
    }
}

@available(iOS 18.0, macOS 15.0, *)
struct TranslationServiceView: View {
    @ObservedObject var viewModel: TranslationServiceViewModel

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .translationTask(viewModel.configuration) { session in
                guard !viewModel.currentBatchTexts.isEmpty else { return }

                let texts = viewModel.currentBatchTexts
                print("🔄 [TranslationService] 执行批量翻译 | 数量=\(texts.count)")

                do {
                    let requests = texts.map { text in
                        TranslationSession.Request(sourceText: text, clientIdentifier: text)
                    }

                    let responses = try await session.translations(from: requests)

                    await MainActor.run {
                        var results: [(String, String)] = []
                        for response in responses {
                            results.append((response.sourceText, response.targetText))
                            print("✅ [TranslationService] 翻译完成 | \(response.sourceText) -> \(response.targetText)")
                        }
                        viewModel.handleResults(results)
                    }
                } catch {
                    print("❌ [TranslationService] 批量翻译失败: \(error)")
                }
            }
    }
}
