import SwiftUI

struct IOSToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
                .font(.system(size: 13))
            Spacer()
            Capsule()
                .fill(configuration.isOn ? Color.green : Color.secondary.opacity(0.2))
                .frame(width: 38, height: 22)
                .overlay(
                    Circle()
                        .fill(Color.white)
                        .shadow(radius: 1, x: 0, y: 1)
                        .padding(2)
                        .offset(x: configuration.isOn ? 8 : -8)
                )
                .onTapGesture {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                        configuration.isOn.toggle()
                    }
                }
        }
        .padding(.vertical, 2)
    }
}

struct TrancyKeyboardSettingsView: View {
    @ObservedObject var settings: KeyboardSettingsStore
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Image("keyboardicon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
                    .padding(10)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(12)

                Text("Trancy Keyboard")
                    .font(.system(size: 18, weight: .bold))
            }
            .padding(.vertical, 30)
            .frame(maxWidth: .infinity)

            List {
                Section(header: Text("Input_Assist".localized)) {
                    Group {
                        Toggle("Double_Pinyin".localized, isOn: $settings.isDoublePinyinEnabled)
                        Toggle("English_Lookup".localized, isOn: $settings.isEnglishLookupEnabled)
                        Toggle("English_Fuzzy_Lookup".localized, isOn: $settings.isEnglishFuzzyLookupEnabled)
                        Toggle("English_Prefix_Lookup".localized, isOn: $settings.isEnglishPrefixLookupEnabled)
                        Toggle("Chinese_Lookup".localized, isOn: $settings.isChineseLookupEnabled)
                        Toggle("Emoji_Search".localized, isOn: $settings.isEmojiEnabled)
                        Toggle("Symbol_Search".localized, isOn: $settings.isSymbolsEnabled)
                        Toggle("Pinyin_Correction".localized, isOn: $settings.isAutoCorrectEnabled)
                        Toggle("Auto_Composition".localized, isOn: $settings.isAutoSplitEnabled)
                        Toggle("Sliding_Input".localized, isOn: $settings.isSlidingFuzzyEnabled)
                        Toggle("Selection_History".localized, isOn: $settings.isSelectionRecordEnabled)
                        Toggle("Frequency_Adjustment".localized, isOn: $settings.isSelectionFrequencyEnabled)
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Cloud_Sync".localized)
                                    .font(.system(size: 13))
                                if settings.lastSyncTimestamp > 0 {
                                    Text("\("Last_Sync".localized): \(formattedDate(settings.lastSyncTimestamp))")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            
                            if settings.isSyncing {
                                HStack(spacing: 4) {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Syncing".localized)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.trailing, 4)
                            }
                            
                            Toggle("", isOn: $settings.isCloudSyncEnabled)
                        }
                    }
                    .toggleStyle(IOSToggleStyle())
                }
                
                Section(header: Text("Appearance_Theme".localized)) {

                    PickerRow(label: "Candidate_Font_Size".localized, selection: $settings.candidateFontSize) {
                        ForEach(CandidateFontSize.allCases.sorted(by: { $0.chineseSize > $1.chineseSize }), id: \.self) { size in
                            Text(size.displayName).tag(size)
                        }
                    }
                   
                    PickerRow(label: "Candidate_Mode".localized, selection: $settings.currentMode) {
                        ForEach(InputMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    PickerRow(label: "Dual_Output_Mode".localized, selection: $settings.dualCandidateOutputMode) {
                        ForEach(DualCandidateOutputMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                }
                
                Section(header: Text("Interface_Language".localized)) {
                    PickerRow(label: "App_Language_Label".localized, selection: $settings.appLanguage) {
                        ForEach(AppLanguage.allCases, id: \.self) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    PickerRow(label: "Output_Mode".localized, selection: $settings.chineseOutputMode) {
                        ForEach(ChineseOutputMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                }

                Section(header: Text("Shortcut_Settings_Title".localized)) {
                    ShortcutRecorderRow(label: "Translation_Shortcut".localized, shortcut: $settings.translationShortcut)
                    ShortcutRecorderRow(label: "Tab_Toggle_Shortcut".localized, shortcut: $settings.tabToggleShortcut)

                    Group {
                        ShortcutInfoRow(label: "Word_Segmentation".localized, shortcut: "~ ／ ‘")
                        ShortcutInfoRow(label: "Select_Candidate".localized, shortcut: "1 - 9")
                        ShortcutInfoRow(label: "Select_First_Space".localized, shortcut: "Space")
                        ShortcutInfoRow(label: "Select_Shift".localized, shortcut: "Shift")
                        ShortcutInfoRow(label: "Input_Pinyin_Letters".localized, shortcut: "Return")
                        ShortcutInfoRow(label: "Page_Down_Up".localized, shortcut: "- / +")
                        ShortcutInfoRow(label: "Expand_Collapse_Bar".localized, shortcut: "[ / ]")
                    }
                }
            }
            .listStyle(InsetListStyle())
        }
        .frame(width: 300, height: 700)
    }

    private func formattedDate(_ timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct PickerRow<T: Hashable, Content: View>: View {
    let label: String
    @Binding var selection: T
    let content: () -> Content
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
            Spacer()
            Picker("", selection: $selection) {
                content()
            }
            .pickerStyle(MenuPickerStyle())
            .frame(width: 150)
        }
        .padding(.vertical, 2)
    }
}

struct ShortcutInfoRow: View {
    let label: String
    let shortcut: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
            Spacer()
            Text(shortcut)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}

struct ShortcutRecorderRow: View {
    let label: String
    @Binding var shortcut: KeyShortcut
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
            Spacer()
            Button(action: {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            }) {
                Text(isRecording ? "Press_Key".localized : shortcut.displayName)
                    .font(.system(size: 12, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isRecording ? Color.blue.opacity(0.1) : Color.primary.opacity(0.05))
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(isRecording ? Color.blue : Color.clear, lineWidth: 1)
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 2)
    }

    private func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            let newShortcut = KeyShortcut.from(event: event)
            DispatchQueue.main.async {
                self.shortcut = newShortcut
                self.stopRecording()
            }
            return nil // Swallow the event
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
