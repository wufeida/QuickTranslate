import AppKit
import SwiftUI
import Combine

// MARK: - 可接收键盘输入的 NSPanel 子类

private class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - Panel 控制器

class InputTranslationPanel: NSObject {
    private var panel: NSPanel?
    private var monitor: Any?

    @MainActor func show() {
        if let existing = panel {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = InputTranslationView(onClose: { [weak self] in self?.close() })
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(x: 0, y: 0, width: 400, height: 220)

        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 220),
            styleMask: [.fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hosting
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true

        // 居中显示
        if let screen = NSScreen.main {
            let x = screen.visibleFrame.midX - 200
            let y = screen.visibleFrame.midY - 110
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        self.panel = panel
        panel.orderFront(nil)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        panel.alphaValue = 0
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            panel.animator().alphaValue = 1
        }

        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.close()
        }
    }

    @MainActor func close() {
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            panel.animator().alphaValue = 0
        } completionHandler: {
            panel.orderOut(nil)
        }
        self.panel = nil
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}

// MARK: - ViewModel

struct TargetLanguageOption: Identifiable {
    let id: String
    let label: String
}

let availableTargetLanguages: [TargetLanguageOption] = [
    .init(id: "zh",  label: "中文（简体）"),
    .init(id: "cht", label: "中文（繁体）"),
    .init(id: "en",  label: "英语"),
    .init(id: "jp",  label: "日语"),
    .init(id: "kor", label: "韩语"),
    .init(id: "fra", label: "法语"),
    .init(id: "de",  label: "德语"),
]

@MainActor
class InputTranslationViewModel: ObservableObject {
    @Published var inputText: String = ""
    @Published var translatedText: String = ""
    @Published var detectedLanguage: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""
    @Published var targetLanguage: String = SettingsManager.shared.targetLanguage

    func translate() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isLoading = true
        translatedText = ""
        errorMessage = ""
        detectedLanguage = ""

        let service = SettingsManager.shared.makeTranslationService()
        let target = targetLanguage
        Task {
            do {
                let result = try await service.translate(text: text, from: "auto", to: target)
                translatedText = result.translatedText
                detectedLanguage = result.detectedLanguage
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    func copyTranslation() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(translatedText, forType: .string)
    }
}

// MARK: - SwiftUI View

struct InputTranslationView: View {
    let onClose: () -> Void
    @StateObject private var vm = InputTranslationViewModel()
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("输入翻译")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            // 输入区
            ZStack(alignment: .topLeading) {
                if vm.inputText.isEmpty {
                    Text("输入要翻译的内容…")
                        .foregroundStyle(.tertiary)
                        .font(.body)
                        .padding(.top, 8)
                        .padding(.leading, 4)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $vm.inputText)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .background(.clear)
                    .focused($inputFocused)
                    .frame(minHeight: 60, maxHeight: 80)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            // 翻译按钮行
            HStack(spacing: 6) {
                if !vm.detectedLanguage.isEmpty {
                    Text(vm.detectedLanguage)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Picker("", selection: $vm.targetLanguage) {
                    ForEach(availableTargetLanguages) { lang in
                        Text(lang.label).tag(lang.id)
                    }
                }
                .labelsHidden()
                .frame(width: 110)
                .controlSize(.small)
                Button(action: vm.translate) {
                    if vm.isLoading {
                        ProgressView().scaleEffect(0.7).frame(width: 16, height: 16)
                    } else {
                        Text("翻译")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isLoading)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 8)

            // 译文区（有内容才显示）
            if !vm.translatedText.isEmpty || !vm.errorMessage.isEmpty {
                Divider()

                HStack(alignment: .top) {
                    Group {
                        if !vm.errorMessage.isEmpty {
                            Text(vm.errorMessage)
                                .foregroundStyle(.red)
                        } else {
                            Text(vm.translatedText)
                                .textSelection(.enabled)
                        }
                    }
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if !vm.translatedText.isEmpty {
                        Button(action: vm.copyTranslation) {
                            Image(systemName: "doc.on.doc")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("复制译文")
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .frame(width: 400)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                inputFocused = true
            }
        }
    }
}
