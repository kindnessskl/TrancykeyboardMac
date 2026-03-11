import SwiftUI
import InputMethodKit
import Combine

@objc(TrancyIMEController)
@MainActor
final class TrancyIMEController: IMKInputController, @unchecked Sendable {
    private var candidatePanel: NSPanel?
    private var hostingController: NSHostingController<AnyView>?
    private var translationPanel: NSPanel?
    private var translationHostingController: NSHostingController<TranslationResultView>?
    
    private let keyViewModel = KeyViewModel()
    private let settingsStore = KeyboardSettingsStore(currentMode: .chinese)
    private let translationViewModel = TranslationServiceViewModel()
    private var currentInputMode: InputMode = .chinese
    
    private weak var currentClient: (any IMKTextInput)?
    private var cancellables = Set<AnyCancellable>()
    private var lastKnownRect: NSRect = .zero
    private var candidateUserDelta: CGSize = .zero
    private var translationUserDelta: CGSize = .zero
    private var isUpdatingPosition: Bool = false

    private var isShiftToggledEnglish: Bool = false
    private var isShiftDown: Bool = false
    private var wasOtherKeyPressedDuringShift: Bool = false

    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        super.init(server: server, delegate: delegate, client: inputClient)
        self.currentClient = inputClient as? (any IMKTextInput)
        keyViewModel.setTranslationService(translationViewModel)
        setupSettingsBinding()
        setupViewModelBindings()
        checkAndMigrateDatabase()
        
        iCloudSyncManager.shared.performSync()
    }

    private func checkAndMigrateDatabase() {
        let appGroupManager = AppGroupsManager.shared
        guard let mainDbPath = appGroupManager.getDatabasePath("keyboard.db") else {
            return
        }
        
        let v4BundlePath = Bundle.main.path(forResource: "keyboard", ofType: "db")
        
        DatabaseMigrator.shared.runMigrations(dbPath: mainDbPath, patchDbPath: v4BundlePath)
    }

    private func setupSettingsBinding() {
        settingsStore.$currentMode
            .sink { [weak self] mode in
                guard let self = self else { return }
                self.currentInputMode = mode
                self.keyViewModel.switchInputMode(mode)
            }
            .store(in: &cancellables)
    }

    override func activateServer(_ sender: Any!) {
        super.activateServer(sender)
        if let inputClient = sender as? (any IMKTextInput) {
            self.currentClient = inputClient
        }
        keyViewModel.clearInput()
        isShiftToggledEnglish = false
    }

    override func deactivateServer(_ sender: Any!) {
        if keyViewModel.isInSelectionTranslationMode {
            return
        }
        if let inputClient = sender as? (any IMKTextInput) {
            self.currentClient = inputClient
        }
        commitComposition(sender)
        hideCandidateWindow()
        
        iCloudSyncManager.shared.performSync()
        
        super.deactivateServer(sender)
    }

    override func commitComposition(_ sender: Any!) {
        if let inputClient = sender as? (any IMKTextInput) {
            self.currentClient = inputClient
        }
        
        if keyViewModel.isInSelectionTranslationMode && keyViewModel.currentInput.isEmpty {
            return
        }

        if !keyViewModel.currentInput.isEmpty || keyViewModel.isInSelectionTranslationMode {
            commitText(keyViewModel.currentInput)
            keyViewModel.clearInput()
        }
    }

    private func setupViewModelBindings() {
        keyViewModel.onTextOutput = { [weak self] text in self?.commitText(text) }
        keyViewModel.onMarkedTextUpdate = { [weak self] text in self?.updateMarkedText(text) }
        keyViewModel.onCandidatesUpdate = { [weak self] candidates in
            guard let self = self else { return }
            self.updateCandidateUI(candidates, input: self.keyViewModel.currentInput)
        }
        keyViewModel.onCandidatesWithTranslationsUpdate = { [weak self] candidates, translations in
            guard let self = self else { return }
            self.updateCandidateUI(candidates, translations: translations, input: self.keyViewModel.currentInput)
        }
        keyViewModel.onClearMarkedText = { [weak self] in self?.updateMarkedText("") }
    }

    override func recognizedEvents(_ sender: Any!) -> Int {
        return Int(NSEvent.EventTypeMask.keyDown.rawValue | NSEvent.EventTypeMask.flagsChanged.rawValue)
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event = event else { return false }

        if let inputClient = sender as? (any IMKTextInput) {
            self.currentClient = inputClient
        } else if let client = self.client() {
            self.currentClient = client
        }

        let flags = event.modifierFlags
        let isCommandPressed = flags.contains(.command)
        let isOptionPressed = flags.contains(.option)
        let isControlPressed = flags.contains(.control)
        let isCapsLockHardwareOn = flags.contains(.capsLock)
        let currentModifiers = flags.intersection(KeyShortcut.mask).rawValue
        let translationShortcut = settingsStore.translationShortcut
        let isTranslationKey = event.keyCode == translationShortcut.keyCode && 
                             currentModifiers == translationShortcut.modifiers
        
        let tabShortcut = settingsStore.tabToggleShortcut
        let isTabToggleKey = event.keyCode == tabShortcut.keyCode && 
                           currentModifiers == tabShortcut.modifiers

        if event.type == .keyDown {
            if isTranslationKey { 
                _ = translateSelectedText()
                return true  
            }
            if isTabToggleKey { 
                _ = toggleActiveLayer()
                return true  
            }
        }
   
        if isCommandPressed || isControlPressed { return false }
        if isOptionPressed && !isTranslationKey { return false }
       
        let isEnglishMode = isShiftToggledEnglish || isCapsLockHardwareOn
        let shouldForceLowercase = isShiftToggledEnglish
        if event.type == .flagsChanged {
            let isShiftNowDown = flags.contains(.shift)
            if isShiftNowDown && !isShiftDown {
                isShiftDown = true
                wasOtherKeyPressedDuringShift = false
            } else if !isShiftNowDown && isShiftDown {
                isShiftDown = false
                if !wasOtherKeyPressedDuringShift {
                    if isShiftToggledEnglish {
                        isShiftToggledEnglish = false  
                    } else {
                        isShiftToggledEnglish = true  
                    }
                    
                    if !keyViewModel.currentInput.isEmpty || keyViewModel.isInSelectionTranslationMode {
                        commitComposition(sender)
                    }
                }
            }
            return false 
        }

        if event.type == .keyDown {
            if isShiftDown { wasOtherKeyPressedDuringShift = true }
            
            let isShiftPressed = flags.contains(.shift)
            let rep = event.keyCode.representative
            if isEnglishMode {
                if !keyViewModel.currentInput.isEmpty {
                    commitComposition(sender)
                }
                if shouldForceLowercase && isCapsLockHardwareOn {
                    switch rep {
                    case .alphabet(let letter):
                        let finalChar = isShiftPressed ? letter.uppercased() : letter.lowercased()
                        commitText(finalChar)
                        return true
                    case .punctuation(let key):
                        commitText(isShiftPressed ? key.shiftingKeyText : key.keyText)
                        return true
                    default: break
                    }
                }
                return false
            }

            switch rep {
            case .alphabet(let letter):
                handleAlphabet(letter)
                return true
            case .separator:
                let isBackquote = event.keyCode == KeyCode.Symbol.VK_BACKQUOTE
                let pKey: PunctuationKey = isBackquote ? .backquote : .quote

                if isShiftPressed {
                    return handlePunctuation(pKey, isShift: true)
                }
                if !keyViewModel.currentInput.isEmpty {
                    handleSeparator()
                    return true
                }
                return handlePunctuation(pKey, isShift: false)
            case .number(let n):
                if isShiftPressed { return false }
                let idx = (n == 0) ? 9 : n - 1
                return selectIndex(idx)
            case .punctuation(let key):
                if !keyViewModel.currentInput.isEmpty || keyViewModel.isInSelectionTranslationMode {
                    if key == .minus { return pageUp() }
                    if key == .equal { return pageDown() }
                    if key == .bracketLeft {
                        return toggleExpansion(force: false)
                    }
                    if keyViewModel.isExpanded { return pageDown() }
                    if key == .bracketRight {
                        return toggleExpansion(force: true)
                    }
                }
                return handlePunctuation(key, isShift: isShiftPressed || isShiftToggledEnglish)
            case .backspace:
                return handleBackspace()
            case .space:
                return handleSpace()
            case .return:
                return handleReturn()
            case .tab:
                return false  
            case .arrow(let dir):
                return moveHighlight(direction: dir)
            case .escape:
                hideCandidateWindow()
                hideTranslationWindow()
                return clearInput()
            default:
                return false
            }
        }
        return false
    }

    override func inputText(_ string: String!, client sender: Any!) -> Bool {
        if !keyViewModel.currentInput.isEmpty || keyViewModel.isInSelectionTranslationMode {
            return true
        }
        if !isShiftToggledEnglish {
            if let char = string?.first, char.isLetter && char.isLowercase {
                handleAlphabet(string)
                return true
            }
        }
        return false
    }

    private var hasMarkedText: Bool = false

    private func updateMarkedText(_ text: String) {
        let client = currentClient ?? self.client()
        guard let client = client else { 
            hasMarkedText = false
            return 
        }
        
        if text.isEmpty {
            if hasMarkedText {
                client.setMarkedText("", selectionRange: NSMakeRange(0, 0), replacementRange: NSMakeRange(NSNotFound, 0))
                hasMarkedText = false
            }
            hideCandidateWindow()
        } else {
            let attributes = [NSAttributedString.Key.underlineStyle: NSUnderlineStyle.single.rawValue]
            let attrString = NSAttributedString(string: text, attributes: attributes)
            client.setMarkedText(attrString, selectionRange: NSMakeRange(text.count, 0), replacementRange: NSMakeRange(NSNotFound, 0))
            hasMarkedText = true
        }
    }

    private func commitText(_ text: String) {
        let client = currentClient ?? self.client()
        guard let client = client else { return }
        
        if text.isEmpty && !hasMarkedText { return }
        
        client.insertText(text, replacementRange: NSMakeRange(NSNotFound, 0))
        hasMarkedText = false
    }

    private func updateCandidateUI(_ candidates: [Candidate], translations: [[String]]? = nil, input: String = "") {
        if candidates.isEmpty {
            hideCandidateWindow()
            hideTranslationWindow()
            return
        }

        if keyViewModel.isInSelectionTranslationMode && candidates.first?.pinyin == "translated" {
            hideCandidateWindow()
            showTranslationResult(candidates.first!.text)
            return
        }

        hideTranslationWindow()

        let modeView = KeyboardModeViewFactory.createModeView(
            for: currentInputMode,
            candidates: candidates,
            translations: translations,
            input: input,
            handler: self, 
            settings: settingsStore,
            activeLayer: keyViewModel.activeLayer,
            highlightedIndex: keyViewModel.highlightedIndex,
            currentPage: keyViewModel.currentPage,
            pageSize: keyViewModel.pageSize,
            pageBreakpoints: keyViewModel.pageBreakpoints,
            candidateWidths: keyViewModel.candidateWidths,
            isExpanded: keyViewModel.isExpanded
        )

        let rootView = ZStack {
            modeView
            if #available(macOS 15.0, *) {
                TranslationServiceView(viewModel: translationViewModel)
            }
        }

        if candidatePanel == nil {
            setupCandidatePanel(with: AnyView(rootView))
        } else {
            hostingController?.rootView = AnyView(rootView)
        }
        showCandidateWindow()
    }

    private enum PanelType {
        case candidate, translation
    }

    private func calculateDefaultPosition(for type: PanelType) -> NSPoint {
        let client = currentClient ?? self.client()
        var rect = NSRect.zero
        
        if let client = client {
            let selectionRange = client.selectedRange()
            if selectionRange.location != NSNotFound && selectionRange.length > 0 {
                client.attributes(forCharacterIndex: selectionRange.location, lineHeightRectangle: &rect)
                if rect != .zero { self.lastKnownRect = rect }
            } else if self.lastKnownRect != .zero {
                rect = self.lastKnownRect
            } else {
                client.attributes(forCharacterIndex: 0, lineHeightRectangle: &rect)
                if rect != .zero { self.lastKnownRect = rect }
            }
        }

        let windowHeight: CGFloat = (type == .candidate) ? 
            ((currentInputMode == .chinesePreview && !keyViewModel.isExpanded) ? 70 : (keyViewModel.isExpanded ? 400 : 36)) : 180
        
        return NSPoint(x: rect.origin.x, y: rect.origin.y - windowHeight - 5)
    }

    private func clampPosition(_ pos: NSPoint, width: CGFloat, height: CGFloat, anchorRect: NSRect) -> NSPoint {
        var x = pos.x
        var y = pos.y
        
        if let screen = NSScreen.main {
            let f = screen.visibleFrame
            
            if x + width > f.maxX { x = f.maxX - width }
            if x < f.minX { x = f.minX }
            
            if y < f.minY {
                y = anchorRect.origin.y + anchorRect.size.height + 5
            }
            
            if y + height > f.maxY { y = f.maxY - height }
            if y < f.minY { y = f.minY }
        }
        return NSPoint(x: x, y: y)
    }

    private func setupCandidatePanel(with view: AnyView) {
        let controller = NSHostingController(rootView: view)
        self.hostingController = controller
        
        controller.view.wantsLayer = true
        controller.view.layer?.backgroundColor = NSColor.clear.cgColor

        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        
        panel.isFloatingPanel = true
        panel.level = .mainMenu
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        
        panel.contentView = controller.view
        self.candidatePanel = panel
        
        NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: panel, queue: .main) { [weak panel] _ in
            guard let panelFrame = panel?.frame else { return }
            Task { @MainActor [weak self] in
                guard let self = self, !self.isUpdatingPosition else { return }
                let defaultPos = self.calculateDefaultPosition(for: .candidate)
                self.candidateUserDelta = CGSize(width: panelFrame.origin.x - defaultPos.x, height: panelFrame.origin.y - defaultPos.y)
            }
        }
    }

    private func showCandidateWindow() {
        updateWindowPosition()
        candidatePanel?.orderFrontRegardless()
    }

    private func hideCandidateWindow() { candidatePanel?.orderOut(nil) }

    private func showTranslationResult(_ text: String) {
        let rootView = TranslationResultView(
            text: text,
            fontSize: 16,
            onSelect: { [weak self] in
                self?.commitText(text)
                self?.keyViewModel.clearInput()
            },
            onClose: { [weak self] in
                self?.keyViewModel.clearInput()
            }
        )

        if translationPanel == nil {
            setupTranslationPanel(with: rootView)
        } else {
            translationHostingController?.rootView = rootView
        }

        updateTranslationWindowPosition()
        translationPanel?.orderFrontRegardless()
    }

    private func setupTranslationPanel(with view: TranslationResultView) {
        let controller = NSHostingController(rootView: view)
        self.translationHostingController = controller
        
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        panel.isFloatingPanel = true
        panel.level = .mainMenu
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        
        panel.contentView = controller.view
        self.translationPanel = panel

        NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: panel, queue: .main) { [weak panel] _ in
            guard let panelFrame = panel?.frame else { return }
            Task { @MainActor [weak self] in
                guard let self = self, !self.isUpdatingPosition else { return }
                let defaultPos = self.calculateDefaultPosition(for: .translation)
                self.translationUserDelta = CGSize(width: panelFrame.origin.x - defaultPos.x, height: panelFrame.origin.y - defaultPos.y)
            }
        }
    }

    private func hideTranslationWindow() {
        translationPanel?.orderOut(nil)
    }

    private func updateTranslationWindowPosition() {
        guard let panel = translationPanel else { return }
        
        self.isUpdatingPosition = true
        let defaultPos = calculateDefaultPosition(for: .translation)
        let targetPos = NSPoint(x: defaultPos.x + translationUserDelta.width, y: defaultPos.y + translationUserDelta.height)
        let finalPos = clampPosition(targetPos, width: 320, height: 180, anchorRect: self.lastKnownRect)
        
        panel.setFrame(NSRect(x: finalPos.x, y: finalPos.y, width: 320, height: 180), display: true)
        self.isUpdatingPosition = false
    }

    private func updateWindowPosition() {
        guard let panel = candidatePanel else { return }
        
        self.isUpdatingPosition = true
        let defaultPos = calculateDefaultPosition(for: .candidate)
        let windowWidth: CGFloat = 700
        let windowHeight: CGFloat = (currentInputMode == .chinesePreview && !keyViewModel.isExpanded) ? 70 : (keyViewModel.isExpanded ? 400 : 36)
        
        let targetPos = NSPoint(x: defaultPos.x + candidateUserDelta.width, y: defaultPos.y + candidateUserDelta.height)
        let finalPos = clampPosition(targetPos, width: windowWidth, height: windowHeight, anchorRect: self.lastKnownRect)

        panel.setFrame(NSRect(x: finalPos.x, y: finalPos.y, width: windowWidth, height: windowHeight), display: true)
        self.isUpdatingPosition = false
    }

    private func translateSelectedText() -> Bool {
        let client = currentClient ?? self.client()
        guard let client = client else { return false }
        let range = client.selectedRange()
        
        var textToTranslate: String?
        
        if range.location != NSNotFound && range.length > 0 {
            var rect = NSRect.zero
            client.attributes(forCharacterIndex: range.location, lineHeightRectangle: &rect)
            if rect != .zero {
                self.lastKnownRect = rect
            }

            if let attrString = client.attributedSubstring(from: range) {
                textToTranslate = attrString.string.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        if textToTranslate == nil || textToTranslate!.isEmpty {
            if let clipboardString = NSPasteboard.general.string(forType: .string) {
                textToTranslate = clipboardString.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        guard let text = textToTranslate, !text.isEmpty else {
            return false
        }
         
        keyViewModel.handleSelectedTextTranslation(text)
        return true
    }
    
    override func menu() -> NSMenu! {
        let menu = NSMenu()
        menu.addItem(withTitle: "Keyboard_Settings_Title".localized, action: #selector(openSettings), keyEquivalent: "")
        menu.addItem(withTitle: "Guide_Title_FuzzyPinyin".localized, action: #selector(openFuzzySettings), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Action_exit".localized, action: #selector(quitService), keyEquivalent: "")
        return menu
    }

    @objc private func openSettings() {
        let settingsView = TrancyKeyboardSettingsView(settings: settingsStore)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 700), styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
        window.center()
        window.title = "Keyboard_Settings_Title".localized
        window.contentView = NSHostingView(rootView: settingsView)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openFuzzySettings() {
        let fuzzyView = FuzzyPinyinSettingsView()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 700), styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
        window.center()
        window.title = "Fuzzy_Pinyin_Title".localized
        window.contentView = NSHostingView(rootView: fuzzyView)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitService() { NSApp.terminate(nil) }

}

extension TrancyIMEController: KeyboardActionHandler {
    func handleAlphabet(_ letter: String) { keyViewModel.handleInput(letter) }
    func handleSeparator() { keyViewModel.handleSeparator() }
    func handleBackspace() -> Bool { return keyViewModel.handleDeleteKey() }
    func handleSpace() -> Bool {
        if !keyViewModel.currentInput.isEmpty || keyViewModel.isInSelectionTranslationMode { keyViewModel.handleSpaceKey(); return true }
        return false
    }
    func handleReturn() -> Bool {
        if !keyViewModel.currentInput.isEmpty || keyViewModel.isInSelectionTranslationMode { commitText(keyViewModel.currentInput); keyViewModel.clearInput(); return true }
        return false
    }
    func handlePunctuation(_ key: PunctuationKey, isShift: Bool) -> Bool {
        let textToInsert = isShift ? key.shiftingKeyText : key.chineseSymbol
        if !keyViewModel.currentInput.isEmpty || keyViewModel.isInSelectionTranslationMode {
            keyViewModel.selectIndex(0)
            keyViewModel.clearInput()
        }
        commitText(textToInsert)
        return true
    }
    func selectIndex(_ index: Int, layer: ActiveLayer? = nil) -> Bool {
        if !keyViewModel.currentInput.isEmpty || keyViewModel.isInSelectionTranslationMode { keyViewModel.selectIndex(index, layer: layer); return true }
        return false
    }
    func selectCandidate(_ candidate: Candidate, layer: ActiveLayer? = nil) -> Bool {
        if !keyViewModel.currentInput.isEmpty || keyViewModel.isInSelectionTranslationMode { keyViewModel.selectCandidate(candidate, layer: layer); return true }
        return false
    }
    func moveHighlight(direction: Direction) -> Bool {
        if !keyViewModel.currentInput.isEmpty || keyViewModel.isInSelectionTranslationMode { keyViewModel.moveHighlight(direction: direction); return true }
        return false
    }
    func pageDown() -> Bool {
        if !keyViewModel.currentInput.isEmpty || keyViewModel.isInSelectionTranslationMode { keyViewModel.pageDown(); return true }
        return false
    }
    func pageUp() -> Bool {
        if !keyViewModel.currentInput.isEmpty || keyViewModel.isInSelectionTranslationMode { keyViewModel.pageUp(); return true }
        return false
    }
    func toggleActiveLayer() -> Bool {
        if !keyViewModel.currentInput.isEmpty || keyViewModel.isInSelectionTranslationMode { keyViewModel.toggleActiveLayer(); return true }
        return false
    }
    func toggleExpansion(force: Bool?) -> Bool {
        if !keyViewModel.currentInput.isEmpty || keyViewModel.isInSelectionTranslationMode { keyViewModel.toggleExpansion(force: force); return true }
        return false
    }
    func clearInput() -> Bool {
        if !keyViewModel.currentInput.isEmpty || keyViewModel.isInSelectionTranslationMode { keyViewModel.clearInput(); return true }
        return false
    }
}
