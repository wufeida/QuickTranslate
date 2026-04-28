import SwiftUI
import AppKit
import Carbon

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .tabItem { Label("通用", systemImage: "gear") }
            EngineSettingsTab()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .tabItem { Label("翻译引擎", systemImage: "globe") }
        }
        .padding(.top, 8)
        .frame(width: 440, height: 300)
    }
}

// MARK: - 通用设置

private struct GeneralSettingsTab: View {
    @ObservedObject private var settings = SettingsManager.shared

    private let labelWidth: CGFloat = 120
    private let controlWidth: CGFloat = 160

    var body: some View {
        VStack(spacing: 10) {
            row("目标语言") {
                Picker("", selection: $settings.targetLanguage) {
                    Text("中文（简体）").tag("zh")
                    Text("中文（繁体）").tag("cht")
                    Text("英语").tag("en")
                    Text("日语").tag("jp")
                    Text("韩语").tag("kor")
                    Text("法语").tag("fra")
                    Text("德语").tag("de")
                }
                .labelsHidden()
                .frame(width: controlWidth)
            }

            row("剪贴板历史条数") {
                HStack(spacing: 6) {
                    TextField("", value: $settings.clipboardHistoryLimit, formatter: clipboardLimitFormatter)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 56)
                        .multilineTextAlignment(.center)
                    Text("条（1-100）")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .frame(width: controlWidth, alignment: .leading)
            }

            Divider()

            row("剪贴板历史快捷键") {
                HotkeyRecorderView(keyCode: $settings.clipboardHotkeyCode,
                                   modifiers: $settings.clipboardHotkeyModifiers)
                    .frame(width: controlWidth)
            }

            row("划词翻译快捷键") {
                HotkeyRecorderView(keyCode: $settings.hotkeyCode,
                                   modifiers: $settings.hotkeyModifiers)
                    .frame(width: controlWidth)
            }

            row("截图翻译快捷键") {
                HotkeyRecorderView(keyCode: $settings.ocrHotkeyCode,
                                   modifiers: $settings.ocrHotkeyModifiers)
                    .frame(width: controlWidth)
            }

            row("输入翻译快捷键") {
                HotkeyRecorderView(keyCode: $settings.inputHotkeyCode,
                                   modifiers: $settings.inputHotkeyModifiers)
                    .frame(width: controlWidth)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func row(_ label: String, @ViewBuilder control: () -> some View) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .frame(width: labelWidth, alignment: .trailing)
                .foregroundColor(.primary)
            control()
        }
    }

    private var clipboardLimitFormatter: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .none
        f.minimum = 1
        f.maximum = 100
        return f
    }
}

// MARK: - 翻译引擎设置

private struct EngineSettingsTab: View {
    @ObservedObject private var settings = SettingsManager.shared
    @State private var selected: TranslationEngine = SettingsManager.shared.selectedEngine

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 2) {
                ForEach(TranslationEngine.allCases, id: \.self) { engine in
                    HStack(spacing: 8) {
                        Image(systemName: engineIcon(engine))
                            .foregroundColor(engine == settings.selectedEngine ? .accentColor : .secondary)
                            .frame(width: 20)
                        Text(engine.displayName)
                            .foregroundColor(engine == settings.selectedEngine ? .accentColor : .primary)
                        Spacer()
                        if engine == settings.selectedEngine {
                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundColor(.accentColor)
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(selected == engine ? Color.accentColor.opacity(0.12) : Color.clear)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { selected = engine }
                }
                Spacer()
            }
            .padding(8)
            .frame(width: 150)

            Divider()

            EngineConfigPanel(engine: selected)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.top, 4)
    }

    private func engineIcon(_ engine: TranslationEngine) -> String {
        switch engine {
        case .baidu: return "b.circle"
        case .youdao: return "y.circle"
        }
    }
}

private struct EngineConfigPanel: View {
    let engine: TranslationEngine
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(engine.displayName).font(.headline)
                Spacer()
                if settings.selectedEngine == engine {
                    Label("使用中", systemImage: "checkmark.circle.fill")
                        .font(.caption).foregroundStyle(.green)
                } else {
                    Button("设为默认") { settings.selectedEngine = engine }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
            }

            Divider()

            switch engine {
            case .baidu:
                LabeledField(label: "App ID", placeholder: "输入百度 App ID", text: $settings.baiduAppID)
                LabeledField(label: "Secret Key", placeholder: "输入百度 Secret Key", text: $settings.baiduSecretKey, secure: true)
            case .youdao:
                LabeledField(label: "App Key", placeholder: "输入有道 App Key", text: $settings.youdaoAppKey)
                LabeledField(label: "App Secret", placeholder: "输入有道 App Secret", text: $settings.youdaoAppSecret, secure: true)
            }

            Spacer()
        }
        .padding(16)
    }
}

private struct LabeledField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var secure: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            if secure {
                SecureField(placeholder, text: $text).textFieldStyle(.roundedBorder)
            } else {
                TextField(placeholder, text: $text).textFieldStyle(.roundedBorder)
            }
        }
    }
}

// MARK: - 快捷键录制控件（可复用）

private struct HotkeyRecorderView: NSViewRepresentable {
    @Binding var keyCode: Int
    @Binding var modifiers: Int

    func makeNSView(context: Context) -> HotkeyRecorderNSView {
        HotkeyRecorderNSView(keyCode: $keyCode, modifiers: $modifiers)
    }
    func updateNSView(_ nsView: HotkeyRecorderNSView, context: Context) {
        nsView.keyCodeBinding = $keyCode
        nsView.modifiersBinding = $modifiers
        nsView.refresh()
    }
}

class HotkeyRecorderNSView: NSView {
    var keyCodeBinding: Binding<Int>
    var modifiersBinding: Binding<Int>
    private var isRecording = false
    private let label = NSTextField(labelWithString: "")

    init(keyCode: Binding<Int>, modifiers: Binding<Int>) {
        self.keyCodeBinding = keyCode
        self.modifiersBinding = modifiers
        super.init(frame: NSRect(x: 0, y: 0, width: 140, height: 24))
        wantsLayer = true
        layer?.cornerRadius = 5
        layer?.borderWidth = 1
        updateAppearance()

        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        label.alignment = .center
        label.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        refresh()
    }

    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }
    override var intrinsicContentSize: NSSize { NSSize(width: 140, height: 24) }

    override func mouseDown(with event: NSEvent) {
        isRecording = true
        window?.makeFirstResponder(self)
        label.stringValue = "请按下快捷键…"
        layer?.borderColor = NSColor.controlAccentColor.cgColor
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { return }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard !flags.isEmpty else { return }

        keyCodeBinding.wrappedValue = Int(event.keyCode)
        modifiersBinding.wrappedValue = HotkeyManager.carbonModifiers(from: flags)

        isRecording = false
        refresh()
        updateAppearance()
        window?.makeFirstResponder(nil)
    }

    override func resignFirstResponder() -> Bool {
        if isRecording {
            isRecording = false
            refresh()
            updateAppearance()
        }
        return super.resignFirstResponder()
    }

    func refresh() {
        label.stringValue = HotkeyManager.displayString(
            keyCode: keyCodeBinding.wrappedValue,
            modifiers: modifiersBinding.wrappedValue
        )
    }

    private func updateAppearance() {
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        layer?.borderColor = NSColor.separatorColor.cgColor
    }
}
